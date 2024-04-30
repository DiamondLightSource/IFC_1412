-- Command flow for read/write commands

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

    -- Data flow control
    signal stage_enable : std_ulogic_vector(1 to 4);
    signal stage_ready : std_ulogic_vector(1 to 4);
    signal stage_3_guard : std_ulogic;
    signal stage_1_guard : std_ulogic;

    signal bank_open_guard : std_ulogic;
    signal bank_open_enable : std_ulogic;
    signal bank_open_ready : std_ulogic;
    signal out_request_guard : std_ulogic;
    signal out_request_enable : std_ulogic;
    signal out_request_ready : std_ulogic;

    -- Used to stretch bank_open_ok_i if stage(2) cannot be loaded, either
    -- because it is not ready or if extra is being loaded
    signal reset_open_ok : std_ulogic;
    signal last_bank_open_ok : std_ulogic := '0';
    signal bank_open_ok : std_ulogic;


    -- Computes ready, valid_in, valid_out from ready, guard, enable, valid
    procedure compute_enable(
        valid_in : std_ulogic; ready_in : std_ulogic; guard : std_ulogic;
        signal ready_out : out std_ulogic;
        signal write_enable : out std_ulogic)
    is
        variable enable_store : std_ulogic;
    begin
        enable_store := not valid_in or ready_in;
        ready_out <= guard and enable_store;
        write_enable <= enable_store;
    end;

begin
    with skid_buffer.valid select
        input_request <=
            skid_buffer when '1',
            mux_request_i when others;

    -- Check whether stage 3 is ready to take the successful open result, if
    -- not the open_ok flag will be stretched until it is
    reset_open_ok <= stage_ready(3) and not stage(2).extra;
    bank_open_ok <= bank_open_ok_i or last_bank_open_ok;

    -- Only accept a new open when the out stage is ready and we're not blocked
    -- (need to look forward to the next state of bank_open_ok)
    bank_open_guard <= not bank_open_ok or reset_open_ok;
    compute_enable(
        bank_open_o.valid, bank_open_ok_i, bank_open_guard,
        bank_open_ready, bank_open_enable);

    -- Loading of out_request
    out_request_guard <= bank_open_ok;
    compute_enable(
        out_request_o.valid, out_request_ok_i, out_request_guard,
        out_request_ready, out_request_enable);

    -- Four pipeline stages with input guards on stages 1 and 3.  Written from
    -- bottom to top to reflect backwards propagation of ready flags
    compute_enable(
        stage(4).valid, stage(4).extra or out_request_ok_i, '1',
        stage_ready(4), stage_enable(4));
    stage_3_guard <=
        stage(2).extra or (bank_open_ok and out_request_ready);
    compute_enable(
        stage(3).valid, stage_ready(4), stage_3_guard,
        stage_ready(3), stage_enable(3));
    compute_enable(
        stage(2).valid, stage_ready(3), '1',
        stage_ready(2), stage_enable(2));
    stage_1_guard <= input_request.extra or bank_open_ready;
    compute_enable(
        stage(1).valid, stage_ready(2), stage_1_guard,
        stage_ready(1), stage_enable(1));

    process (clk_i) begin
        if rising_edge(clk_i) then
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

            -- -----------------------------------------------------------------
            -- Pipeline stages

            -- Initial stage is guarded by bank open enable
            if stage_enable(1) then
                if stage_1_guard then
                    stage(1) <= input_request;
                else
                    stage(1).valid <= '0';
                end if;
            end if;

            -- Waiting for open request
            if stage_enable(2) then
                stage(2) <= stage(1);
            end if;

            -- Loading out request, needs to wait for open to complete
            if stage_enable(3) then
                if stage_3_guard then
                    stage(3) <= stage(2);
                else
                    stage(3).valid <= '0';
                end if;
            end if;

            -- Final stage waiting for out request
            if stage_enable(4) then
                stage(4) <= stage(3);
            end if;

            -- -----------------------------------------------------------------
            -- Open and Out requests

            -- Load open request
            if bank_open_enable then
                if bank_open_guard then
                    bank_open_o <= (
                        bank => input_request.bank,
                        row => input_request.row,
                        valid => input_request.valid and not input_request.extra
                    );
                else
                    bank_open_o.valid <= '0';
                end if;
            end if;
            -- Hang onto open_ok while unable to hand over to out processing
            if reset_open_ok then
                last_bank_open_ok <= '0';
            elsif bank_open_ok_i then
                last_bank_open_ok <= '1';
            end if;

            -- Load out request
            if out_request_enable then
                if out_request_guard then
                    out_request_o <= (
                        direction => stage(2).direction,
                        bank => stage(2).bank,
                        valid => stage(2).valid and not stage(2).extra
                    );
                else
                    out_request_o.valid <= '0';
                end if;
            end if;
            -- Let banks know about any extra commands in the pipeline
            out_request_extra_o <= stage(2).valid and stage(2).extra;

            -- -----------------------------------------------------------------
            -- Output generation

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
