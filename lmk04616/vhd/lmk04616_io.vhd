-- IO mapping for multiplexed LMK04616 pins

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lmk04616_io is
    port (
        -- IO pins
        pad_LMK_CTL_SEL_o : out std_ulogic;
        pad_LMK_SCL_o : out std_ulogic;
        pad_LMK_SCS_L_o : out std_ulogic;
        pad_LMK_SDIO_io : inout std_logic;
        pad_LMK_RESET_L_o : out std_ulogic;
        pad_LMK_SYNC_io : inout std_logic;
        pad_LMK_STATUS_io : inout std_logic_vector(1 downto 0);

        lmk_ctl_sel_i : in std_ulogic;      -- LMK select (0 => SYS, 1 => ACQ)

        -- SPI interface
        lmk_scl_i : in std_ulogic;          -- clock
        lmk_scs_l_i : in std_ulogic;        -- chip select
        lmk_mosi_i : in std_ulogic;         -- data to slave
        lmk_miso_o : out std_ulogic;        -- data from slave
        lmk_moen_i : in std_ulogic;         -- enable output to slave

        -- Other controls
        lmk_reset_l_i : in std_ulogic;
        lmk_sync_i : in std_ulogic;
        lmk_status_o : out std_ulogic_vector(1 downto 0)
    );
end;

architecture arch of lmk04616_io is
begin
    -- Needed for simulation to avoid undriven signals in simulation
    -- pragma translate off
    pad_LMK_STATUS_io <= "ZZ";
    -- pragma translate on

    -- For most signals can just use the default constraint settings, don't need
    -- to instantiate IO buffers
    pad_LMK_CTL_SEL_o <= lmk_ctl_sel_i;
    pad_LMK_SCL_o <= lmk_scl_i;
    pad_LMK_SCS_L_o <= lmk_scs_l_i;
    pad_LMK_RESET_L_o <= lmk_reset_l_i;
    pad_LMK_SYNC_io <= lmk_sync_i;
    lmk_status_o <= pad_LMK_STATUS_io;

    -- The SDIO line is shared and needs a tristate driver
    pad_LMK_SDIO_io <= lmk_mosi_i when lmk_moen_i else 'Z';
    lmk_miso_o <= to_X01(pad_LMK_SDIO_io);
end;

-- vim: set filetype=vhdl:
