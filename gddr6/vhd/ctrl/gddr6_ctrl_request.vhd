-- Command flow for read/write commands

-- This implements a four stage pipeline supporting two stages of request
-- validation against the bank status: first the bank being operated on is
-- checked to be open on the correct row, then the output request is validated
-- for timing.  Requests need to advance on every tick (hence the use of a four
-- stage pipeline for two validation stages) so that write mask data can flow
-- in a timely manner.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_command_defs.all;
use work.gddr6_ctrl_defs.all;

entity gddr6_ctrl_request is
    port (
        clk_i : in std_ulogic;

        -- Selected request from read/write multiplexer
        mux_request_i : in core_request_t;
        mux_ready_o : out std_ulogic := '1';

        -- Command completion notification
        completion_o : out request_completion_t := IDLE_COMPLETION;

        -- Check bank open and reserve
        bank_open_o : out bank_open_t := IDLE_OPEN_REQUEST;
        bank_open_ok_i : in std_ulogic;

        -- Bank read/write request
        out_request_o : out out_request_t := IDLE_OUT_REQUEST;
        out_request_ok_i : in std_ulogic;
        out_request_extra_o : out std_ulogic := '0';

        -- CA Commands out to PHY
        command_o : out ca_command_t;
        command_valid_o : out std_ulogic := '0'
    );
end;

architecture arch of gddr6_ctrl_request is
    type core_request_array_t is array(natural range <>) of core_request_t;
    signal stage : core_request_array_t(1 to 4)
        := (others => IDLE_CORE_REQUEST);

    signal skid_buffer : core_request_t := IDLE_CORE_REQUEST;
    signal input_request : core_request_t;

    -- Used to stretch bank_open_ok_i if stage(2) cannot be loaded, either
    -- because it is not ready or if extra is being loaded
    signal last_bank_open_ok : std_ulogic := '0';


    -- The following three update_{request,open,out} procedures perform
    -- essentially the same function: update the request_out pipeline register
    -- from request_in and compute the ready_out variable based on the following
    -- logic:
    --  * If request_out will be consumed (ready_in set) or if request_out is
    --    not valid then load and consume incoming data if possible.
    --  * If guard is not set then treat the incoming data as not yet ready and
    --    do not load it.
    --  * Report ready_out if any incoming data will be consumed
    -- Note that ready_out is a variable and so must be processed at the correct
    -- point in the process to avoid accidentially becoming registered!

    procedure update_request(
        request_in : core_request_t;
        signal request_out : out core_request_t;
        ready_in : std_ulogic;
        variable ready_out : out std_ulogic;
        guard : std_ulogic := '1')
    is
        variable enable_store : std_ulogic;
    begin
        enable_store := ready_in or not request_out.valid;
        ready_out := enable_store and guard;
        if enable_store then
            if guard then
                request_out <= request_in;
            else
                request_out.valid <= '0';
            end if;
        end if;
    end;

    procedure update_open(
        request_in : core_request_t;
        signal request_out : out bank_open_t;
        ready_in : std_ulogic;
        variable ready_out : out std_ulogic;
        guard : std_ulogic)
    is
        variable enable_store : std_ulogic;
    begin
        enable_store := ready_in or not request_out.valid;
        ready_out := enable_store and guard;
        if enable_store then
            if guard then
                request_out <= (
                    bank => request_in.bank,
                    row => request_in.row,
                    valid => request_in.valid and not request_in.extra
                );
            else
                request_out.valid <= '0';
            end if;
        end if;
    end;

    procedure update_out(
        request_in : core_request_t;
        signal request_out : out out_request_t;
        ready_in : std_ulogic;
        variable ready_out : out std_ulogic;
        guard : std_ulogic)
    is
        variable enable_store : std_ulogic;
    begin
        enable_store := ready_in or not request_out.valid;
        ready_out := enable_store and guard;
        if enable_store then
            if guard then
                request_out <= (
                    direction => request_in.direction,
                    bank => request_in.bank,
                    valid => request_in.valid and not request_in.extra
                );
            else
                request_out.valid <= '0';
            end if;
        end if;
    end;


begin
    with skid_buffer.valid select
        input_request <=
            skid_buffer when '1',
            mux_request_i when others;

    process (clk_i)
        -- The following variables are updated in sequence by the update_
        -- procedures.  The ordering is essential so that combinatorial control
        -- data in variables flows from top to bottom in the code below; note
        -- that this is opposite to the order of data flow.
        --
        -- WARNING: if the code below is reordered incorrectly it is
        -- possible for one or more of these signals to be unintentionally
        -- converted to a register signal.
        variable stage_ready : std_ulogic_vector(1 to 4);
        variable out_request_ready : std_ulogic;
        variable bank_open_ready : std_ulogic;

        -- Stretched version of bank_open_ok_i, valid until open transferred to
        -- out request and stage(3)
        variable bank_open_ok : std_ulogic;
        -- Set when bank open will be consumed on this tick
        variable reset_open_ok : std_ulogic;

    begin
        if rising_edge(clk_i) then
            -- Check whether stage 3 is ready to take the successful open
            -- result, if not the open_ok flag will be stretched until it is
            bank_open_ok := bank_open_ok_i or last_bank_open_ok;

            -- Four pipeline stages with input guards on stages 1 and 3 together
            -- with open and out request stages.
            -- Written from bottom to top to reflect backwards propagation
            -- of ready flags and guards.

            -- Output of final stage, blocks until out request accepted
            -- Generates stage_ready(4) flag
            update_request(
                request_in => stage(3),
                request_out => stage(4),
                ready_in => stage(4).extra or out_request_ok_i,
                ready_out => stage_ready(4));

            -- Loading of out_request_o
            -- Generates out_request_ready flag
            update_out(
                request_in => stage(2),
                request_out => out_request_o,
                ready_in => out_request_ok_i,
                ready_out => out_request_ready,
                guard => bank_open_ok_i or last_bank_open_ok);

            -- Request concurrently loaded with out_request_o
            -- Generates stage_ready(3) flag
            update_request(
                request_in => stage(2),
                request_out => stage(3),
                ready_in => stage_ready(4),
                ready_out => stage_ready(3),
                guard =>
                    stage(2).extra or (bank_open_ok and out_request_ready));

            -- Output of first stage
            -- Generates stage_ready(2) flag
            update_request(
                request_in => stage(1),
                request_out => stage(2),
                ready_in => stage_ready(3),
                ready_out => stage_ready(2));

            -- Loading of open request
            -- Generates bank_open_ready flag
            reset_open_ok := stage_ready(3) and not stage(2).extra;
            update_open(
                request_in => input_request,
                request_out => bank_open_o,
                ready_in => bank_open_ok_i,
                ready_out => bank_open_ready,
                guard => not bank_open_ok or reset_open_ok);

            -- Loading of input data concurrently with bank_open_o
            -- Generates stage_ready(1) flag
            update_request(
                request_in => input_request,
                request_out => stage(1),
                ready_in => stage_ready(2),
                ready_out => stage_ready(1),
                guard => input_request.extra or bank_open_ready);


            -- Input enable and skid buffer
            if stage_ready(1) then
                -- Input is being consumed, enable input and clear skid buffer
                skid_buffer.valid <= '0';
                mux_ready_o <= '1';
            elsif mux_request_i.valid and mux_ready_o then
                -- First stage can't take this, so need to load skid buffer
                skid_buffer <= mux_request_i;
                mux_ready_o <= '0';
            end if;

            -- Hang onto open_ok while unable to hand over to out processing
            if reset_open_ok then
                last_bank_open_ok <= '0';
            elsif bank_open_ok_i then
                last_bank_open_ok <= '1';
            end if;

            -- Let banks know about any extra commands in the pipeline
            out_request_extra_o <= stage(2).valid and stage(2).extra;

            -- Emit final command and completion
            command_o <= stage(4).command;
            command_valid_o <=
                stage(4).valid and
                (out_request_ok_i or stage(4).extra);

            -- Command completion
            completion_o <= (
                direction => stage(4).direction,
                advance => stage(4).write_advance,
                enables => stage(4).command.ca3,
                valid => out_request_ok_i
            );
        end if;
    end process;
end;
