-- SPI control interface to dual LMK04616 controllers
--
-- Only meaningful on the IFC_1412 card with its dual control over the LMK

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.register_defs.all;

entity lmk04616 is
    port (
        clk_i : in std_ulogic;

        -- Register interface
        write_strobe_i : in std_ulogic;
        write_data_i : in reg_data_t;
        write_ack_o : out std_ulogic;
        read_strobe_i : in std_ulogic;
        read_data_o : out reg_data_t;
        read_ack_o : out std_ulogic;

        -- IO pins
        pad_LMK_CTL_SEL_o : out std_ulogic;
        pad_LMK_SCL_o : out std_ulogic;
        pad_LMK_SCS_L_o : out std_ulogic;
        pad_LMK_SDIO_io : inout std_logic;
        pad_LMK_RESET_L_o : out std_ulogic;
        pad_LMK_SYNC_io : inout std_logic;
        pad_LMK_STATUS_io : inout std_logic_vector(1 downto 0)
    );
end;

architecture arch of lmk04616 is
    signal lmk_ctl_sel : std_ulogic;

    signal lmk_scl : std_ulogic;
    signal lmk_scs_l : std_ulogic;
    signal lmk_mosi : std_ulogic;
    signal lmk_miso : std_ulogic;
    signal lmk_moen : std_ulogic;

    signal lmk_reset_l : std_ulogic;
    signal lmk_sync : std_ulogic;
    signal lmk_status : std_ulogic_vector(1 downto 0);

    signal spi_start : std_ulogic;
    signal spi_read_write_n : std_ulogic;
    signal spi_address : std_ulogic_vector(14 downto 0);
    signal spi_data_mosi : std_ulogic_vector(7 downto 0);
    signal spi_data_miso : std_ulogic_vector(7 downto 0);
    signal spi_busy : std_ulogic;

begin
    io : entity work.lmk04616_io port map (
        pad_LMK_CTL_SEL_o => pad_LMK_CTL_SEL_o,
        pad_LMK_SCL_o => pad_LMK_SCL_o,
        pad_LMK_SCS_L_o => pad_LMK_SCS_L_o,
        pad_LMK_SDIO_io => pad_LMK_SDIO_io,
        pad_LMK_RESET_L_o => pad_LMK_RESET_L_o,
        pad_LMK_SYNC_io => pad_LMK_SYNC_io,
        pad_LMK_STATUS_io => pad_LMK_STATUS_io,

        lmk_ctl_sel_i => lmk_ctl_sel,

        lmk_scl_i => lmk_scl,
        lmk_scs_l_i => lmk_scs_l,
        lmk_mosi_i => lmk_mosi,
        lmk_miso_o => lmk_miso,
        lmk_moen_i => lmk_moen,

        lmk_reset_l_i => lmk_reset_l,
        lmk_sync_i => lmk_sync,
        lmk_status_o => lmk_status
    );


    spi : entity work.spi_master generic map (
        -- Maximum SPI clock is 20 MHz, so need to divide 250 MHz clock by 16
        LOG_SCLK_DIVISOR => 4,
        ADDRESS_BITS => 15,
        DATA_BITS => 8
    ) port map (
        clk_i => clk_i,

        csn_o => lmk_scs_l,
        sclk_o => lmk_scl,
        mosi_o => lmk_mosi,
        moen_o => lmk_moen,
        miso_i => lmk_miso,

        start_i => spi_start,
        r_wn_i => spi_read_write_n,
        command_i => spi_address,
        data_i => spi_data_mosi,
        busy_o => spi_busy,
        response_o => spi_data_miso
    );


    control : entity work.lmk04616_control port map (
        clk_i => clk_i,

        write_strobe_i => write_strobe_i,
        write_data_i => write_data_i,
        write_ack_o => write_ack_o,
        read_strobe_i => read_strobe_i,
        read_data_o => read_data_o,
        read_ack_o => read_ack_o,

        lmk_ctl_sel_o => lmk_ctl_sel,

        lmk_reset_l_o => lmk_reset_l,
        lmk_sync_o => lmk_sync,
        lmk_status_i => lmk_status,

        spi_read_write_n_o => spi_read_write_n,
        spi_address_o => spi_address,
        spi_start_o => spi_start,
        spi_busy_i => spi_busy,
        spi_data_i => spi_data_miso,
        spi_data_o => spi_data_mosi
    );
end;

-- vim: set filetype=vhdl:
