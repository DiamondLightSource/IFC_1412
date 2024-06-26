-- SPI control interface to dual LMK04616 controllers

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lmk04616 is
    port (
        clk_i : in std_ulogic;

        -- Config
        command_select_i : in std_ulogic;   -- Select LMK to observe and control
        select_valid_o : out std_ulogic;    -- Set while selection is valid
        status_o : out std_ulogic_vector(1 downto 0);
        reset_i : in std_ulogic;
        sync_i : in std_ulogic;

        -- Writing
        write_strobe_i : in std_ulogic;
        write_ack_o : out std_ulogic;
        read_write_n_i : in std_ulogic;
        address_i : in std_ulogic_vector(14 downto 0);
        data_i : in std_ulogic_vector(7 downto 0);
        -- Determines which LMK is targeted by this write
        write_select_i : in std_ulogic;

        -- Reading (returns result of previous write)
        read_strobe_i : in std_ulogic;
        read_ack_o : out std_ulogic;
        data_o : out std_ulogic_vector(7 downto 0);

        -- IO pins
        pad_LMK_CTL_SEL_o : out std_ulogic;
        pad_LMK_SCL_o : out std_ulogic;
        pad_LMK_SCS_L_o : out std_ulogic;
        pad_LMK_SDIO_io : inout std_logic;
        pad_LMK_RESET_L_o : out std_ulogic;
        pad_LMK_SYNC_o : out std_logic;
        pad_LMK_STATUS_i : in std_logic_vector(1 downto 0)
    );
end;

architecture arch of lmk04616 is
    signal lmk_ctl_sel : std_ulogic;
    signal lmk_scl : std_ulogic;
    signal lmk_scs_l : std_ulogic;
    signal lmk_mosi : std_ulogic;
    signal lmk_miso : std_ulogic;
    signal lmk_moen : std_ulogic;

    signal status : std_ulogic_vector(1 downto 0);

    signal spi_start : std_ulogic;
    signal spi_busy : std_ulogic;

begin
    io : entity work.lmk04616_io port map (
        pad_LMK_CTL_SEL_o => pad_LMK_CTL_SEL_o,
        pad_LMK_SCL_o => pad_LMK_SCL_o,
        pad_LMK_SCS_L_o => pad_LMK_SCS_L_o,
        pad_LMK_SDIO_io => pad_LMK_SDIO_io,
        pad_LMK_RESET_L_o => pad_LMK_RESET_L_o,
        pad_LMK_SYNC_o => pad_LMK_SYNC_o,
        pad_LMK_STATUS_i => pad_LMK_STATUS_i,

        lmk_ctl_sel_i => lmk_ctl_sel,

        lmk_scl_i => lmk_scl,
        lmk_scs_l_i => lmk_scs_l,
        lmk_mosi_i => lmk_mosi,
        lmk_miso_o => lmk_miso,
        lmk_moen_i => lmk_moen,

        lmk_reset_l_i => not reset_i,
        lmk_sync_i => sync_i,
        lmk_status_o => status
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
        r_wn_i => read_write_n_i,
        command_i => address_i,
        data_i => data_i,
        busy_o => spi_busy,
        response_o => data_o
    );


    control : entity work.lmk04616_control port map (
        clk_i => clk_i,

        command_select_i => command_select_i,
        select_valid_o => select_valid_o,
        status_i => status,
        status_o => status_o,

        write_strobe_i => write_strobe_i,
        write_ack_o => write_ack_o,
        write_select_i => write_select_i,
        read_strobe_i => read_strobe_i,
        read_ack_o => read_ack_o,

        lmk_ctl_sel_o => lmk_ctl_sel,
        spi_start_o => spi_start,
        spi_busy_i => spi_busy
    );
end;
