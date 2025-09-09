-- Helper for register_share

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity register_share is
    generic (
        COUNT : natural := 2;
        ADDRESS_WIDTH : natural := 0;
        DATA_WIDTH : natural := 32
    );
    port (
        clk_i : in std_ulogic;

        -- Multiplexed interfaces
        mux_address_i : in
            unsigned_array(0 to COUNT-1)(ADDRESS_WIDTH-1 downto 0)
                := (others => (others => '0'));
        mux_data_i : in vector_array(0 to COUNT-1)(DATA_WIDTH-1 downto 0)
            := (others => (others => '0'));
        mux_data_o : out vector_array(0 to COUNT-1)(DATA_WIDTH-1 downto 0);
        mux_strobe_i : in std_ulogic_vector(0 to COUNT-1);
        mux_ack_o : out std_ulogic_vector(0 to COUNT-1) := (others => '0');

        -- Shared interface
        shared_address_o : out unsigned(ADDRESS_WIDTH-1 downto 0);
        shared_strobe_o : out std_ulogic := '0';
        shared_data_i : in std_ulogic_vector(DATA_WIDTH-1 downto 0)
            := (others => '0');
        shared_data_o : out std_ulogic_vector(DATA_WIDTH-1 downto 0);
        shared_ack_i : in std_ulogic := '1'
    );
end;

architecture arch of register_share is
    signal pending_strobes : std_ulogic_vector(0 to COUNT-1)
        := (others => '0');
    signal selection : natural range 0 to COUNT-1;
    signal busy : std_ulogic := '0';

    -- Priority decoding of incoming or pending strobes
    function count_zeros(data : std_ulogic_vector) return natural is
    begin
        for i in data'RANGE loop
            if data(i) then
                return i;
            end if;
        end loop;
        return 0;
    end;


begin
    process (clk_i)
        procedure advance_selection is
            variable strobes_in : std_ulogic_vector(0 to COUNT-1);
            variable next_busy : std_ulogic;
            variable next_selection : natural range 0 to COUNT-1;
        begin
            strobes_in := pending_strobes or mux_strobe_i;
            next_busy := vector_or(strobes_in);
            next_selection := count_zeros(strobes_in);

            mux_ack_o <= (others => '0');
            shared_address_o <= mux_address_i(next_selection);
            shared_data_o <= mux_data_i(next_selection);
            shared_strobe_o <= next_busy;
            pending_strobes <=
                strobes_in and
                not compute_strobe(next_selection, COUNT, next_busy);
            busy <= next_busy;
            selection <= next_selection;
        end;

        procedure process_response is
        begin
            -- Waiting for response from shared endpoint
            mux_ack_o(selection) <= shared_ack_i;
            mux_data_o(selection) <= shared_data_i;
            shared_strobe_o <= '0';
            pending_strobes <= pending_strobes or mux_strobe_i;
            busy <= not shared_ack_i;
        end;

    begin
        if rising_edge(clk_i) then
            if busy then
                process_response;
            else
                advance_selection;
            end if;
        end if;
    end process;
end;
