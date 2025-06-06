-- Input multiplexer for read/write commands

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_defs.all;
use work.gddr6_ctrl_tuning_defs.all;
use work.gddr6_ctrl_command_defs.all;

entity gddr6_ctrl_mux is
    port (
        clk_i : in std_ulogic;

        -- Direction control: priority or polling.  In priority mode starvation
        -- is possible, otherwise we avoid this by polling.
        priority_mode_i : in std_ulogic;
        -- In priority mode this is the selected direction
        priority_direction_i : in direction_t;
        -- If refresh is running out of time and cannot access a bank this
        -- request will stall progress by blocking acceptance of requests
        enable_i : in std_ulogic;
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

architecture arch of gddr6_ctrl_mux is
    -- Direction selection.  Fairly simple minded: when there is only one choice
    -- that is automatically selected, otherwise we maintain a "preferred
    -- direction" which is either fixed or alternates depending on whether
    -- priority mode is enabled.
    signal poll_counter : natural range 0 to MUX_POLL_INTERVAL
        := MUX_POLL_INTERVAL;
    signal preferred_direction : direction_t := DIR_READ;

    -- The request direction must not change when extra commands (write mask
    -- values) follow the selected command
    signal current_direction : direction_t := DIR_READ;
    signal enabled : std_ulogic := '0';
    signal lock_direction : std_ulogic := '0';
    -- Don't change direction too quickly as there is a cost to this
    signal switch_count : natural range 0 to MUX_SWITCH_DELAY := 0;

    -- Double buffering, one for output, and an extra skid buffer to handle
    -- propagation of unready state
    signal out_request : core_request_t := IDLE_CORE_REQUEST;
    signal skid_request : core_request_t := IDLE_CORE_REQUEST;
    signal input_ready : std_ulogic;

    -- Input as selected by the multiplexer
    signal selected_request : core_request_t;

    -- Choose next direction according to configured settings and incoming
    -- requests: if both are available then 
    impure function next_direction return direction_t is
    begin
        if read_request_i.valid and write_request_i.valid then
            return preferred_direction;
        elsif read_request_i.valid then
            return DIR_READ;
        elsif write_request_i.valid then
            return DIR_WRITE;
        else
            return current_direction;
        end if;
    end;

begin
    -- Accept unless the skid buffer is busy or if we're disabled
    input_ready <= not skid_request.valid and enabled;

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

    -- Input multiplexer, block input when not enabled
    selected_request <=
        IDLE_CORE_REQUEST when not enabled else
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
                poll_counter <= MUX_POLL_INTERVAL;
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
                enabled <= enable_i;

                -- Block changes away from the preferred direction until a
                -- timer has expired.  This ensures that we keep a single
                -- direction consistently where possible.
                -- Maintain the direction switch counter
                if next_direction = preferred_direction then
                    switch_count <= MUX_SWITCH_DELAY;
                elsif switch_count > 0 then
                    switch_count <= switch_count - 1;
                end if;
                -- Switch if appropriate
                if switch_count = 0 or next_direction = preferred_direction then
                    current_direction <= next_direction;
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
