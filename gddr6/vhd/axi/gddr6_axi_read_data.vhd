-- AXI R stream interface

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_axi_defs.all;

entity gddr6_axi_read_data is
    port (
        clk_i : in std_ulogic;

        -- FIFO from AXI RA data interface
        command_i : in burst_command_t;
        command_ready_o : out std_ulogic := '0';

        -- Data FIFO
        fifo_data_i : in read_data_t;
        fifo_data_ready_o : out std_ulogic := '1';

        -- AXI R interface
        axi_data_o : out axi_read_data_t := IDLE_AXI_READ_DATA;
        axi_ready_i : in std_ulogic
    );
end;

architecture arch of gddr6_axi_read_data is
    signal command : burst_command_t := IDLE_BURST_COMMAND;

    -- Support for skipping data at start and end of burst response
    signal skip_data : std_ulogic := '0';
    -- Records whether new data is needed after this command
    signal consume_data : std_ulogic;

    -- We use a skid buffer for the incoming data.  This is expensive (the data
    -- array is *large*) but the combinatorial decision on consume_data is
    -- complex enough already.
    signal data_skid : read_data_t := IDLE_READ_DATA;

begin
    vars :
    process (clk_i)
        -- Manages input data stream and associated skid buffer
        procedure advance_data(data_ready : std_ulogic) is
        begin
            if data_ready then
                -- When data is being taken allow it to pass through
                data_skid.valid <= '0';
                fifo_data_ready_o <= '1';
            elsif fifo_data_i.valid and fifo_data_ready_o then
                -- When not ready put the data to one side
                data_skid <= fifo_data_i;
                fifo_data_ready_o <= '0';
            end if;
        end;


        -- Returns the result of advancing command by one tick.  Not used when
        -- command.count is zero
        function step_command(command : burst_command_t) return burst_command_t
        is
            variable result : burst_command_t;
        begin
            result := command;
            result.count := command.count - 1;
            result.offset := command.offset + command.step;
            return result;
        end;

        -- Checks if the given command will consume the data
        function command_consumes_data(command : burst_command_t)
            return std_ulogic
        is
            variable next_offset : unsigned(6 downto 0);
        begin
            next_offset := command.offset + command.step;
            return command.count ?= 0 or next_offset(5 downto 0) ?= 0;
        end;



        -- Advance the command state when the AXI output is ready for a new
        -- result
        procedure advance_command(command_ready : std_ulogic)
        is
            variable load_new_command : std_ulogic;
            variable next_command : burst_command_t;
        begin
            -- This doesn't quite follow the standard "ready or not valid" load
            -- process because "not valid and skip_data" is a special state, and
            -- of course we have a lot of state management to do anyway
            load_new_command := '0';
            if command_ready then
                if command.valid then
                    if skip_data then
                        skip_data <= '0';
                    elsif command.count > 0 then
                        -- Advance current command to next count and work out if
                        -- data will be consumed
                        next_command := step_command(command);
                        command <= next_command;
                        consume_data <= command_consumes_data(next_command);
                    elsif not command.offset(6) and
                          not command.invalid_burst then
                        -- count is zero but we didn't consume the last half of
                        -- the SG burst, so enter the special skip state.  We
                        -- can't load the next command until skip is complete.
                        skip_data <= '1';
                        command.valid <= '0';
                    else
                        load_new_command := '1';
                    end if;
                else
                    load_new_command := '1';
                end if;
            elsif not command.valid and not skip_data then
                load_new_command := '1';
            end if;

            -- Acknowledge commands after receipt
            command_ready_o <= load_new_command;
            if load_new_command then
                command <= command_i;
                skip_data <=
                    command_i.offset(6) and command_i.valid and
                    not command_i.invalid_burst;
                consume_data <= command_consumes_data(command_i);
            end if;
        end;


        -- Advance the AXI response when we can
        procedure advance_axi(axi_valid : std_ulogic; data : read_data_t) is
            -- Compute AXI read RESP code from command and data status.
            -- The AXI specification really doesn't give us many options for the
            -- error code, which means even in the case of an AXI protocol
            -- error all we can return is SLVERR (slave error).
            impure function resp return std_ulogic_vector is
            begin
                if command.invalid_burst or not data.ok then
                    return "10";        -- SLVERR
                else
                    return "00";        -- OKAY
                end if;
            end;

        begin
            if axi_ready_i or not axi_data_o.valid then
                axi_data_o <= (
                    id => command.id,
                    resp => resp,
                    data => data.data,
                    last => command.count ?= 0,
                    valid => command.valid and axi_valid
                );
            end if;
        end;


        variable new_data : read_data_t;
        variable axi_ready : std_ulogic;
        variable axi_valid : std_ulogic;
        variable data_ready : std_ulogic;
        variable command_ready : std_ulogic;

    begin
        if rising_edge(clk_i) then
            if data_skid.valid then
                new_data := data_skid;
            else
                new_data := fifo_data_i;
            end if;

            -- Find when AXI is ready for another output
            axi_ready := axi_ready_i or not axi_data_o.valid;

            -- Compute the appropriate control flags according to the data
            -- management state
            if skip_data then
                -- Skip unwanted data at start or end of AXI burst
                axi_valid := '0';
                data_ready := '1';
                command_ready := new_data.valid;
            elsif command.invalid_burst then
                -- During an invalid burst we don't transfer data
                axi_valid := command.valid;
                data_ready := '0';
                command_ready := axi_valid and axi_ready;
            else
                axi_valid := command.valid and new_data.valid;
                data_ready :=
                    axi_valid and axi_ready and consume_data;
                command_ready := axi_valid and axi_ready;
            end if;


            advance_command(command_ready);
            advance_data(data_ready);
            advance_axi(axi_valid, new_data);
        end if;
    end process;
end;
