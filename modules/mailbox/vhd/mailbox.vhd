-- Implementation of IC2 mailbox for MMC communication

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;

entity mailbox is
    generic (
        MB_ADDRESS : std_ulogic_vector(6 downto 0) := 7X"60";
        -- Address of the byte where the slot number will be written
        SLOT_ADDRESS : natural := 8
    );
    port (
        clk_i : in std_ulogic;

        -- Single register interface
        -- Can be left unconnected if not required
        write_strobe_i : in std_ulogic := '0';
        write_data_i : in reg_data_t := (others => '0');
        write_ack_o : out std_ulogic;
        read_strobe_i : in std_ulogic := '0';
        read_data_o : out reg_data_t;
        read_ack_o : out std_ulogic;

        scl_i : in std_ulogic;
        sda_io : inout std_logic;

        slot_o : out unsigned(3 downto 0)
    );
end;

architecture arch of mailbox is
    -- Signals from master to slave (us)
    signal scl_in : std_ulogic;
    signal sda_in : std_ulogic;
    -- Signals from slave to master
    signal sda_out : std_ulogic;

    -- Core to slave
    signal rx_data : std_ulogic_vector(7 downto 0);
    signal rx_start : std_ulogic;
    signal rx_strobe : std_ulogic;
    signal rx_accept : std_ulogic;
    signal rx_ack : std_ulogic;
    signal tx_data : std_ulogic_vector(7 downto 0);
    signal tx_ack : std_ulogic;
    signal tx_strobe : std_ulogic;

begin
    io : entity work.mailbox_io port map (
        clk_i => clk_i,

        scl_i => scl_i,
        sda_io => sda_io,

        scl_o => scl_in,
        sda_o => sda_in,
        sda_i => sda_out
    );

    core : entity work.i2c_core port map (
        clk_i => clk_i,

        scl_i => scl_in,
        sda_i => sda_in,
        sda_o => sda_out,

        rx_data_o => rx_data,
        rx_start_o => rx_start,
        rx_restart_o => open,
        rx_strobe_o => rx_strobe,
        rx_accept_i => rx_accept,
        rx_ack_i => rx_ack,

        tx_data_i => tx_data,
        tx_ack_i => tx_ack,
        tx_strobe_o => tx_strobe,

        error_o => open,
        stop_o => open
    );

    slave : entity work.mailbox_slave generic map (
        MB_ADDRESS => MB_ADDRESS,
        SLOT_ADDRESS => SLOT_ADDRESS
    ) port map (
        clk_i => clk_i,

        rx_data_i => rx_data,
        rx_start_i => rx_start,
        rx_strobe_i => rx_strobe,
        rx_accept_o => rx_accept,
        rx_ack_o => rx_ack,

        tx_data_o => tx_data,
        tx_ack_o => tx_ack,
        tx_strobe_i => tx_strobe,

        write_strobe_i => write_strobe_i,
        write_data_i => write_data_i,
        write_ack_o => write_ack_o,
        read_strobe_i => read_strobe_i,
        read_data_o => read_data_o,
        read_ack_o => read_ack_o,

        slot_o => slot_o
    );
end;
