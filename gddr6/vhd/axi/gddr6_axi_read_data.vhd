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
        fifo_command_i : in burst_command_t;
        fifo_ready_o : out std_ulogic := '0';

        -- Data FIFO
        fifo_data_i : in std_logic_vector(511 downto 0);
        fifo_data_ok_i : in std_ulogic;
        fifo_data_valid_i : in std_ulogic;
        fifo_data_ready_o : out std_ulogic := '0';

        -- AXI R interface
        axi_data_o : out axi_read_data_t;
        axi_ready_i : in std_ulogic
    );
end;

architecture arch of gddr6_axi_read_data is
    signal command : burst_command_t := IDLE_BURST_COMMAND;
    signal first_transfer : std_ulogic := '1';

    type data_t is record
        data : std_ulogic_vector(511 downto 0);
        ok : std_ulogic;
        valid : std_ulogic;
    end record;
    constant IDLE_DATA : data_t := (data => (others => '0'), others => '0');
    -- We use a skid buffer for the incoming data.  This is expensive (the data
    -- array is *large*) but the combinatorial decision on consume_data is
    -- complex enough already.
    signal data_skid : data_t := IDLE_DATA;
    signal data_buffer : data_t := IDLE_DATA;

    signal axi_data_out : axi_read_data_t := (
        id => (others => '0'),
        data => (others => '0'),
        resp => (others => '0'),
        last => '0',
        valid => '0'
    );

begin
vars:
    process (clk_i)

        -- Manage input data stream, loads new data if available and
        -- load_new_data is set, returns data_valid if the newly loaded (or
        -- original if not loaded) data is valid.
        procedure advance_data(
            load_new_data : std_ulogic;
            variable new_data : out data_t)
        is
            impure function get_data_in return data_t is
            begin
                return (
                    data => fifo_data_i,
                    ok => fifo_data_ok_i,
                    valid => fifo_data_valid_i
                );
            end;

        begin
            -- Load data buffer when data consumed or when empty
            if load_new_data or not data_buffer.valid then
                if data_skid.valid then
                    new_data := data_skid;
                else
                    new_data := get_data_in;
                end if;
                data_buffer <= new_data;
                -- Manage skid buffer and input enable
                data_skid.valid <= '0';
                fifo_data_ready_o <= '1';
            else
                -- If we're consuming input data we need to put it to one side
                if fifo_data_valid_i and fifo_data_ready_o then
                    data_skid <= get_data_in;
                    fifo_data_ready_o <= '0';
                end if;
                new_data := data_buffer;
            end if;
        end;



        -- Advance the command state when the AXI output is ready for a new
        -- result
        procedure advance_command(axi_ready : std_ulogic)
        is
            variable load_command : std_ulogic;
        begin
            load_command :=
                not command.valid or (axi_ready and command.count ?= 0);
            if load_command then
                command <= fifo_command_i;
                first_transfer <= '1';
            elsif axi_ready then
                command.count <= command.count - 1;
                command.offset <= command.offset + command.step;
                first_transfer <= '0';
            end if;

            -- Acknowledge loading of command on next cycle
            fifo_ready_o <= load_command and fifo_command_i.valid;
        end;


        -- Updates AXI output
        -- The individual fields of axi_data_out are written separately as
        -- axi_data_out.data needs to be assigned separately
        procedure advance_axi(
            data : data_t; skip_data : std_ulogic;
            variable next_command : out std_ulogic)
        is
            variable load_axi : std_ulogic;
            variable command_ready : std_ulogic;
        begin
            -- Load or clear when output is ready or we have nothing loaded
            load_axi := axi_ready_i or not axi_data_out.valid;
            -- Skip incoming data when phase mismatch at start or end of AXI
            -- burst
            command_ready :=
                command.valid and
                ((data.valid and not skip_data) or command.invalid_burst);
            next_command := load_axi and command_ready;

            if load_axi then
                axi_data_out.id <= command.id;
                -- The AXI specification really doesn't give us many options for
                -- the error code, which means even in the case of an AXI
                -- protocol error all we can return is SLVERR (slave error).
                if command.invalid_burst or not data.ok then
                    axi_data_out.resp <= "10";        -- SLVERR
                else
                    axi_data_out.resp <= "00";        -- OKAY
                end if;
                axi_data_out.last <= command.count ?= 0;
                axi_data_out.valid <= command_ready;
            end if;
        end;


        -- Determines behaviour of data
        procedure advance_control(
            variable load_new_data : out std_ulogic;
            variable skip_data : out std_ulogic)
        is
        begin
            if first_transfer then
                skip_data := command.offset(6);
            elsif command.count = 0 then
                skip_data := not command.offset(6);
            else
                skip_data := '0';
            end if;

            load_new_data := command.offset(5 downto 0) ?= 0;
        end;


        variable load_new_data : std_ulogic;
        variable skip_data : std_ulogic;
        variable new_data : data_t;
        variable next_command : std_ulogic;

    begin
        if rising_edge(clk_i) then
            advance_control(load_new_data, skip_data);

            advance_data(load_new_data, new_data);

            advance_axi(new_data, skip_data, next_command);

            advance_command(next_command);
        end if;
    end process;

    axi_data_out.data <= data_buffer.data;
    axi_data_o <= axi_data_out;
end;
