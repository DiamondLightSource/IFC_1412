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
        axi_ready_i : in std_ulogic;

        -- Stats
        stats_crc_error_o : out std_ulogic := '0';
        stats_transfer_o : out std_ulogic := '0';
        stats_data_beat_o : out std_ulogic := '0'
    );
end;

architecture arch of gddr6_axi_read_data is
    signal command : burst_command_t := IDLE_BURST_COMMAND;

    -- Support for skipping data at start and end of burst response
    signal skip_data : std_ulogic := '0';

    -- We use a skid buffer for the incoming data.  This is expensive (the data
    -- array is *large*) but the combinatorial decision on consume_data is
    -- complex enough already.
    signal data_skid : read_data_t := IDLE_READ_DATA;

begin
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


        -- Advance command with suitable ping-pong handshake
        procedure load_command(ready : std_ulogic) is
        begin
            if ready then
                if command_ready_o then
                    -- Awkward case: we have to ignore valid in for the moment
                    command.valid <= '0';
                    command_ready_o <= '0';
                else
                    command <= command_i;
                    command_ready_o <= command_i.valid;
                    skip_data <=
                        command_i.offset(6) and command_i.valid and
                        not command_i.invalid_burst;
                end if;
            else
                command_ready_o <= '0';
            end if;
        end;


        -- Advance the command state when the AXI output is ready for a new
        -- result
        procedure advance_command(command_ready : std_ulogic)
        is
            variable load_new_command : std_ulogic;
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
                        -- Advance current command to next count
                        command.count <= command.count - 1;
                        command.offset <= command.offset + command.step;
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
            else
                load_new_command := not command.valid and not skip_data;
            end if;

            load_command(load_new_command);
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

            variable stats_valid : std_ulogic;

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

            stats_valid :=
                (axi_ready_i or not axi_data_o.valid) and
                command.valid and axi_valid;
            stats_crc_error_o <=
                stats_valid and not data.ok and not command.invalid_burst;
            stats_transfer_o  <= stats_valid and command.count ?= 0;
            stats_data_beat_o <= stats_valid;
        end;


        -- Checks whether this command is the last command consuming this data
        function consume_data(command : burst_command_t) return std_ulogic
        is
            variable next_offset : unsigned(6 downto 0);
        begin
            next_offset := command.offset + command.step;
            return command.count ?= 0 or next_offset(5 downto 0) ?= 0;
        end;


        -- Progress of the controller state machine is determined by three flow
        -- control inputs: command.valid, new_data.valid, and axi_ready,
        -- indicating respectively that:
        --
        --  command.valid       A new command state is ready to be processed
        --  new_data.valid      Incoming data is ready to be transmitted
        --  axi_ready           The AXI port is ready to send a new value
        --
        -- All of these ports are controlled by the following three control
        -- flags computed below:
        --
        --  command_ready       Command is consumed, step to next command
        --  data_ready          Data is consumed, advance to next available data
        --  axi_valid           AXI response is available to be sent
        --
        -- Computing these three control flags depends on the command state and
        -- whether data is to be skipped, consumed or held.
        variable new_data : read_data_t;
        variable axi_ready : std_ulogic;
        variable command_ready : std_ulogic;
        variable data_ready : std_ulogic;
        variable axi_valid : std_ulogic;

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
            elsif command.valid and command.invalid_burst then
                -- During an invalid burst we don't transfer data
                axi_valid := '1';
                data_ready := '0';
                command_ready := axi_valid and axi_ready;
            elsif command.valid then
                -- During normal processing advance command and advance data
                -- when consumed
                axi_valid := new_data.valid;
                data_ready := axi_valid and axi_ready and consume_data(command);
                command_ready := axi_valid and axi_ready;
            else
                axi_valid := '0';
                data_ready := '0';
                command_ready := '1';
            end if;


            advance_command(command_ready);
            advance_data(data_ready);
            advance_axi(axi_valid, new_data);
        end if;
    end process;
end;
