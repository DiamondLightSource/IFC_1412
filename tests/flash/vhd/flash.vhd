-- Interface to QSPI configuration FLASH

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.register_defs.all;
use work.register_defines.all;

entity flash is
    port (
        clk_i : in std_ulogic;

        -- Register interface
        write_strobe_i : in std_ulogic_vector(FLASH_REGS_RANGE);
        write_data_i : in reg_data_array_t(FLASH_REGS_RANGE);
        write_ack_o : out std_ulogic_vector(FLASH_REGS_RANGE);
        read_strobe_i : in std_ulogic_vector(FLASH_REGS_RANGE);
        read_data_o : out reg_data_array_t(FLASH_REGS_RANGE);
        read_ack_o : out std_ulogic_vector(FLASH_REGS_RANGE);

        -- User FLASH
        pad_USER_SPI_CS_L_o : out std_ulogic;
        pad_USER_SPI_SCK_o : out std_ulogic;
        pad_USER_SPI_D_io : inout std_ulogic_vector(3 downto 0);
        -- FPGA configuration
        pad_FPGA_CFG_FCS2_B_o : out std_ulogic;
        pad_FPGA_CFG_D_io : inout std_ulogic_vector(7 downto 4)
    );
end;

architecture arch of flash is
begin
    write_ack_o <= (others => '1');
    read_data_o <= (others => (others => '0'));
    read_ack_o <= (others => '1');

    pad_USER_SPI_CS_L_o <= '1';
    pad_USER_SPI_SCK_o <= '1';
    pad_USER_SPI_D_io <= (others => 'Z');
    pad_FPGA_CFG_FCS2_B_o <= '1';
    pad_FPGA_CFG_D_io <= (others => 'Z');
end;
