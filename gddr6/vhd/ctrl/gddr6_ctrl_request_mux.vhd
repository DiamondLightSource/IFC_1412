-- Input multiplexer for read/write commands

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_command_defs.all;
use work.gddr6_ctrl_core_defs.all;

entity gddr6_ctrl_request_mux is
    port (
        clk_i : in std_ulogic;

        -- Selects between read and write requests
        direction_i : in direction_t;
        -- If refresh is running out of time and cannot access a bank this
        -- request will stall progress by blocking acceptance of requests
        stall_i : in std_ulogic;

        -- Write request with handshake and completion
        write_request_i : in core_request_t;
        write_ready_o : out std_ulogic := '0';

        -- Read request with handshake and completion
        read_request_i : in core_request_t;
        read_ready_o : out std_ulogic := '0';

        -- The out_ready_i signal is a complex combinatorial signal and needs
        -- to be registered before being presented above.
        out_request_o : out core_request_t;
        out_ready_i : in std_ulogic
    );
end;

architecture arch of gddr6_ctrl_request_mux is
    -- The request direction must not change when extra commands (write mask
    -- values) follow the selected command
    signal request_direction : direction_t;
    signal stalled : std_ulogic := '0';
    signal lock_direction : std_ulogic := '0';

    -- Double buffering, one for output, and an extra skid buffer to handle
    -- propagation of unready state
    signal out_request : core_request_t := IDLE_CORE_REQUEST;
    signal skid_request : core_request_t := IDLE_CORE_REQUEST;
    signal input_ready : std_ulogic;

    -- Input as selected by the multiplexer
    signal selected_request : core_request_t;

begin
    -- Can always accept unless the skid buffer is busy or if we been
    -- explicitly stalled.
    input_ready <= not skid_request.valid and not stalled;

    -- Input flow control, acknowledge input from selected direction.
    -- These are not properly registered, relying on three registers each.
    with request_direction select
        write_ready_o <=
            input_ready when DIR_WRITE,
            '0' when DIR_READ;
    with request_direction select
        read_ready_o <=
            '0' when DIR_WRITE,
            input_ready when DIR_READ;

    -- Input multiplexer, block input when stalled
    selected_request <=
        IDLE_CORE_REQUEST when stalled else
        write_request_i when request_direction = DIR_WRITE else
        read_request_i;

    process (clk_i)
        variable lock_in : std_ulogic;
    begin
        if rising_edge(clk_i) then
            -- Remember the lock direction in case the producer has a command
            -- gap ... not sure that this is necessary.
            if input_ready and selected_request.valid then
                lock_direction <= selected_request.next_extra;
            end if;

            -- Only update the transfer direction and stall state when not
            -- accepting an input with extra commands following to avoid
            -- splitting such commands.
            lock_in := input_ready and selected_request.valid and
                selected_request.next_extra;
            if not lock_direction and not lock_in then
                stalled <= stall_i;
                request_direction <= direction_i;
            end if;

            -- Load the skid buffer if we are accepting input, the output is not
            -- ready, and the output register is already loaded.
            if out_request.valid and not out_ready_i and input_ready then
                skid_request <= selected_request;
            elsif out_ready_i then
                skid_request.valid <= '0';
            end if;

            -- Update output unless we can't get rid of our current output
            if not out_request.valid or out_ready_i then
                if skid_request.valid then
                    out_request <= skid_request;
                else
                    out_request <= selected_request;
                end if;
            end if;
        end if;
    end process;
    out_request_o <= out_request;
end;
