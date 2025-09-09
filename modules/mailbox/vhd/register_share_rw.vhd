-- Register sharing: supports sharing a single register with address access with
-- multiple users

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity register_share_rw is
    generic (
        COUNT : natural := 2;
        ADDRESS_WIDTH : natural := 0;
        DATA_WIDTH : natural := 32
    );
    port (
        clk_i : in std_ulogic;

        -- Multiplexed interfaces
        mux_write_address_i : in
            unsigned_array(0 to COUNT-1)(ADDRESS_WIDTH-1 downto 0)
            := (others => (others => '0'));
        mux_write_data_i : in vector_array(0 to COUNT-1)(DATA_WIDTH-1 downto 0);
        mux_write_strobe_i : in std_ulogic_vector(0 to COUNT-1);
        mux_write_ack_o : out std_ulogic_vector(0 to COUNT-1);
        mux_read_address_i : in
            unsigned_array(0 to COUNT-1)(ADDRESS_WIDTH-1 downto 0)
            := (others => (others => '0'));
        mux_read_data_o : out vector_array(0 to COUNT-1)(DATA_WIDTH-1 downto 0);
        mux_read_strobe_i : in std_ulogic_vector(0 to COUNT-1);
        mux_read_ack_o : out std_ulogic_vector(0 to COUNT-1);

        -- Shared interface
        shared_write_address_o : out unsigned(ADDRESS_WIDTH-1 downto 0);
        shared_write_data_o : out std_ulogic_vector(DATA_WIDTH-1 downto 0);
        shared_write_strobe_o : out std_ulogic;
        shared_write_ack_i : in std_ulogic;
        shared_read_address_o : out unsigned(ADDRESS_WIDTH-1 downto 0);
        shared_read_data_i : in std_ulogic_vector(DATA_WIDTH-1 downto 0);
        shared_read_strobe_o : out std_ulogic;
        shared_read_ack_i : in std_ulogic
    );
end;

architecture arch of register_share_rw is
begin
    write : entity work.register_share generic map (
        COUNT => COUNT,
        ADDRESS_WIDTH => ADDRESS_WIDTH,
        DATA_WIDTH => DATA_WIDTH
    ) port map (
        clk_i => clk_i,

        mux_address_i => mux_write_address_i,
        mux_data_i => mux_write_data_i,
        mux_strobe_i => mux_write_strobe_i,
        mux_ack_o => mux_write_ack_o,
        shared_address_o => shared_write_address_o,
        shared_data_o => shared_write_data_o,
        shared_strobe_o => shared_write_strobe_o,
        shared_ack_i => shared_write_ack_i
    );

    read : entity work.register_share generic map (
        COUNT => COUNT,
        ADDRESS_WIDTH => ADDRESS_WIDTH,
        DATA_WIDTH => DATA_WIDTH
    ) port map (
        clk_i => clk_i,

        mux_address_i => mux_read_address_i,
        mux_data_o => mux_read_data_o,
        mux_strobe_i => mux_read_strobe_i,
        mux_ack_o => mux_read_ack_o,
        shared_address_o => shared_read_address_o,
        shared_data_i => shared_read_data_i,
        shared_strobe_o => shared_read_strobe_o,
        shared_ack_i => shared_read_ack_i
    );
end;
