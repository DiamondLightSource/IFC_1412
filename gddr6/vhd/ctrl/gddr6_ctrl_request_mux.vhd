-- Input multiplexer for read/write commands

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_command_defs.all;
use work.gddr6_ctrl_core_defs.all;

entity gddr6_ctrl_request_mux is
    generic (
        -- Interval over which the preferred direction alternates in polled mode
        POLL_BITS : natural := 7
    );
    port (
        clk_i : in std_ulogic;

        -- Direction control: priority or polling.  In priority mode starvation
        -- is possible, in priority mode we will try to avoid this by polling.
        priority_mode_i : in std_ulogic;
        -- In priority mode this is the selected direction
        priority_direction_i : in direction_t;
        -- If refresh is running out of time and cannot access a bank this
        -- request will stall progress by blocking acceptance of requests
        stall_i : in std_ulogic;
        -- Reports currently selected direction
        current_direction_o : out direction_t;

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
    -- Direction selection.  Fairly simple minded: when there is only one choice
    -- that is automatically selected, otherwise we maintain a "preferred
    -- direction" which is either fixed or alternates depending on whether
    -- priority mode is enabled.
    signal poll_counter : unsigned(POLL_BITS-1 downto 0) := (others => '0');
    signal preferred_direction : direction_t := DIR_READ;

    -- The request direction must not change when extra commands (write mask
    -- values) follow the selected command
    signal current_direction : direction_t := DIR_READ;
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
    -- Accept unless the skid buffer is busy or if we're explicitly stalled.
    input_ready <= not skid_request.valid and not stalled;

    -- Input flow control, acknowledge input from selected direction.
    -- These are not properly registered, relying on three registers each.
    with current_direction select
        write_ready_o <=
            input_ready when DIR_WRITE,
            '0' when DIR_READ;
    with current_direction select
        read_ready_o <=
            '0' when DIR_WRITE,
            input_ready when DIR_READ;

    -- Input multiplexer, block input when stalled
    selected_request <=
        IDLE_CORE_REQUEST when stalled else
        write_request_i   when current_direction = DIR_WRITE else
        read_request_i    when current_direction = DIR_READ;

    process (clk_i)
        variable lock_in : std_ulogic;
    begin
        if rising_edge(clk_i) then
            -- Update the preferred direction as appropriate.  In priority mode
            -- this determines the preferred direction, otherwise this alterates
            -- on a timer
            if priority_mode_i then
                preferred_direction <= priority_direction_i;
            elsif poll_counter > 0 then
                poll_counter <= poll_counter - 1;
            else
                poll_counter <= POLL_INTERVAL;
                case preferred_direction is
                    when DIR_READ  => preferred_direction <= DIR_WRITE;
                    when DIR_WRITE => preferred_direction <= DIR_READ;
                end case;
            end if;

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

                -- Use the current preferred direction to select the direction
                -- if there is a choice of inputs, otherwise take the only
                -- valid input if present.
                if read_request_i.valid and write_request_i.valid then
                    current_direction <= preferred_direction;
                elsif read_request_i.valid then
                    current_direction <= DIR_READ;
                elsif write_request_i.valid then
                    current_direction <= DIR_WRITE;
                end if;
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
    current_direction_o <= current_direction;
end;
