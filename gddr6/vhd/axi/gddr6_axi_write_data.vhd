-- AXI W stream interface

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.flow_control.all;

use work.gddr6_defs.all;
use work.gddr6_axi_defs.all;

entity gddr6_axi_write_data is
    port (
        clk_i : in std_ulogic;

        -- FIFO from AXI RA data interface
        command_i : in burst_command_t;
        command_ready_o : out std_ulogic := '1';

        -- Data FIFO
        fifo_data_o : out write_data_t := IDLE_WRITE_DATA;
        fifo_ready_i : in std_ulogic;

        -- AXI W interface
        axi_data_i : in axi_write_data_t;
        axi_ready_o : out std_ulogic := '1';

        stats_last_error_o : out std_ulogic := '0';
        stats_data_beat_o : out std_ulogic := '0'
    );
end;

architecture arch of gddr6_axi_write_data is
    signal command : burst_command_t := IDLE_BURST_COMMAND;
    signal data_skid : axi_write_data_t := IDLE_AXI_WRITE_DATA;

begin
    process (clk_i)
        -- Advance command state machine or load new command as appropriate
        procedure advance_command(command_ready : std_ulogic)
        is
            variable load_value : std_ulogic;
        begin
            -- Advance the command counter and state or load a fresh command
            advance_state_machine_and_ping_pong(
                command_i.valid, command_ready,
                command.count ?= 0, command.valid,
                command_ready_o, load_value);
            if load_value then
                if command.valid and command.count ?> 0 then
                    command.count <= command.count - 1;
                    command.offset <= command.offset + command.step;
                else
                    command <= command_i;
                end if;
            end if;
        end;


        -- Advance data input
        procedure advance_data(data_ready : std_ulogic)
        is
            variable load_skid : std_ulogic;
        begin
            advance_half_skid_buffer(
                axi_data_i.valid, data_ready,
                axi_ready_o, data_skid.valid,
                load_skid);
            if load_skid then
                data_skid <= axi_data_i;
            end if;
        end;


        -- Load output when appropriate
        procedure advance_fifo_out(
            next_data : axi_write_data_t;
            fifo_valid : std_ulogic) is
        begin
            if fifo_ready_i or not fifo_data_o.valid then
                fifo_data_o <= (
                    data => next_data.data,
                    byte_mask => next_data.strb,
                    phase => command.offset(6),
                    advance =>
                        command.count ?= 0 or
                        command.offset + command.step ?= 0,
                    valid => fifo_valid
                );
            end if;
            stats_data_beat_o <=
                (fifo_ready_i or not fifo_data_o.valid) and fifo_valid;
        end;


        procedure compute_ready_valid(
            data_valid : std_ulogic;
            variable command_ready : out std_ulogic;
            variable data_ready : out std_ulogic;
            variable fifo_valid : out std_ulogic)
        is
            variable fifo_ready : std_ulogic;
        begin
            fifo_ready := fifo_ready_i or not fifo_data_o.valid;

            if command.valid then
                if command.invalid_burst then
                    -- Process an invalid burst by accepting data but not
                    -- forwarding
                    command_ready := '1';
                    data_ready := '1';
                    fifo_valid := '0';
                else
                    -- A normal burst requires data.  Advance command and data
                    -- when the output FIFO is ready
                    command_ready := fifo_ready and data_valid;
                    data_ready := fifo_ready;
                    fifo_valid := data_valid;
                end if;
            else
                -- If no command then stand still until ready
                command_ready := '0';
                data_ready := '0';
                fifo_valid := '0';
            end if;
        end;


        procedure check_last(next_data : axi_write_data_t) is
        begin
            stats_last_error_o <=
                (command.valid and next_data.valid) and
                to_std_ulogic((next_data.last = '1') /= (command.count = 0));
        end;


        variable next_data : axi_write_data_t;
        variable command_ready : std_ulogic;
        variable data_ready : std_ulogic;
        variable fifo_valid : std_ulogic;

    begin
        if rising_edge(clk_i) then
            if data_skid.valid then
                next_data := data_skid;
            else
                next_data := axi_data_i;
            end if;

            -- Compute validity and ready flags
            compute_ready_valid(
                next_data.valid,
                command_ready, data_ready, fifo_valid);

            -- Advance all interfaces accordingly
            advance_command(command_ready);
            advance_data(data_ready);
            advance_fifo_out(next_data, fifo_valid);

            -- We're not actually looking at last, but it had better be set
            -- when it should be!
            check_last(next_data);
        end if;
    end process;
end;
