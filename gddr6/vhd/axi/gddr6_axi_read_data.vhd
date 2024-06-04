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

    -- Support for skipping data at start and end of burst response
    signal new_command : std_ulogic := '0';
    signal data_skipped : std_ulogic := '0';

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

    signal axi_id : std_logic_vector(3 downto 0);
    signal axi_resp : std_logic_vector(1 downto 0);
    signal axi_last : std_logic;
    signal axi_valid : std_ulogic := '0';

    -- This state is needed to track whether data loaded into data_buffer has
    -- been uploaded to axi
    signal axi_data_valid : std_ulogic := '0';

begin
vars:
    process (clk_i)
        -- Manage input data stream, loads new data if available and
        -- load_new_data is set, returns data_valid if the newly loaded (or
        -- original if not loaded) data is valid.
        procedure advance_data(
            load_new_data : std_ulogic;
            variable data_ok : out std_ulogic;
            variable data_valid : out std_ulogic)
        is
            impure function get_data_in return data_t is
            begin
                return (
                    data => fifo_data_i,
                    ok => fifo_data_ok_i,
                    valid => fifo_data_valid_i
                );
            end;

            variable new_data : data_t;

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

            data_ok := new_data.ok;
            data_valid := new_data.valid;
        end;


        -- Advance the command state when the AXI output is ready for a new
        -- result
        procedure advance_command(load_new_command : std_ulogic) is
        begin
            -- Commands are only acknowledged after receipt, so fifo_ready_o is
            -- normally reset
            fifo_ready_o <= '0';
            if load_new_command or not command.valid then
                if command.valid and command.count ?> 0 then
                    -- Advance current command to next count
                    command.count <= command.count - 1;
                    command.offset <= command.offset + command.step;
                    new_command <= '0';
                elsif fifo_command_i.valid and not fifo_ready_o then
                    command <= fifo_command_i;
                    new_command <= '1';
                    fifo_ready_o <= '1';        -- Acknowledge command
                else
                    new_command <= '0';
                    command.valid <= '0';
                end if;
            end if;
        end;


        -- Advance the AXI response when we can
        procedure advance_axi(
            new_axi_valid : std_ulogic; data_ok : std_ulogic;
            variable load_new_command : out std_ulogic)
        is
            -- Compute AXI read RESP code from command and data status.
            -- The AXI specification really doesn't give us many options for the
            -- error code, which means even in the case of an AXI protocol
            -- error all we can return is SLVERR (slave error).
            function resp(invalid_burst : std_ulogic)
                return std_ulogic_vector is
            begin
                if invalid_burst or not data_ok then
                    return "10";        -- SLVERR
                else
                    return "00";        -- OKAY
                end if;
            end;

        begin
            if axi_ready_i or not axi_valid then
                axi_id <= command.id;
                axi_resp <= resp(command.invalid_burst);
                axi_last <= command.count ?= 0;
                axi_valid <= command.valid and new_axi_valid;
                if command.valid and new_axi_valid then
                    -- Remember if we've consumed any data
                    axi_data_valid <= not command.invalid_burst;
                end if;
            end if;
            load_new_command :=
                (axi_ready_i or not axi_valid) and new_axi_valid;
        end;


        -- Determines whether we need to skip a line of data from the start or
        -- the end of an SG and AXI burst.
        impure function skip_data return std_ulogic is
        begin
            if new_command then
                return command.offset(6) and not data_skipped;
            elsif command.count = 0 then
                return not command.offset(6) and not data_skipped;
            else
                return '0';
            end if;
        end;


        variable load_new_data : std_ulogic;
        variable new_data_ok : std_ulogic;
        variable new_data_valid : std_ulogic;
        variable new_axi_valid : std_ulogic;
        variable load_new_command : std_ulogic;

    begin
        if rising_edge(clk_i) then
            -- Work out whether new data will be needed
            load_new_data :=
--                 not axi_data_valid and
                command.valid and not command.invalid_burst and
                (command.offset(5 downto 0) ?= 0 or new_command or skip_data);

            -- Ensure we have any data we need
            advance_data(load_new_data, new_data_ok, new_data_valid);

            -- Skipping data needs to be handled here.  When skipping the first
            -- line we have to mark it as skipped so that new data can be
            -- generated
            data_skipped <= new_data_valid and skip_data;

            -- Work out whether we're ready to send a new AXI response
            new_axi_valid :=
                (new_data_valid and not skip_data) or command.invalid_burst;

            -- Update the AXI response if appropriate
            advance_axi(new_axi_valid, new_data_ok, load_new_command);

            -- Update the command if consumed
            advance_command(load_new_command);
        end if;
    end process;

    axi_data_o <= (
        id => axi_id,
        data => data_buffer.data,
        resp => axi_resp,
        last => axi_last,
        valid => axi_valid
    );
end;
