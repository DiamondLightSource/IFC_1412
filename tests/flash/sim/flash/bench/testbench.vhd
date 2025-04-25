library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.register_defs.all;
use work.register_defines.all;
use work.sim_support.all;

entity testbench is
end testbench;


architecture arch of testbench is
    signal clk : std_ulogic := '0';

    procedure clk_wait(count : natural := 1) is
    begin
        clk_wait(clk, count);
    end;

    signal write_strobe : std_ulogic_vector(FLASH_REGS_RANGE);
    signal write_data : reg_data_array_t(FLASH_REGS_RANGE);
    signal write_ack : std_ulogic_vector(FLASH_REGS_RANGE);
    signal read_strobe : std_ulogic_vector(FLASH_REGS_RANGE);
    signal read_data : reg_data_array_t(FLASH_REGS_RANGE);
    signal read_ack : std_ulogic_vector(FLASH_REGS_RANGE);

    signal pad_USER_SPI_CS_L : std_ulogic;
    signal pad_USER_SPI_SCK : std_ulogic;
    signal pad_USER_SPI_D : std_logic_vector(3 downto 0);
    signal pad_FPGA_CFG_FCS2_B : std_ulogic;
    signal pad_FPGA_CFG_D : std_logic_vector(7 downto 4);

begin
    clk <= not clk after 2 ns;

    flash : entity work.flash port map (
        clk_i => clk,

        write_strobe_i => write_strobe,
        write_data_i => write_data,
        write_ack_o => write_ack,
        read_strobe_i => read_strobe,
        read_data_o => read_data,
        read_ack_o => read_ack,

        pad_USER_SPI_CS_L_o => pad_USER_SPI_CS_L,
        pad_USER_SPI_SCK_o => pad_USER_SPI_SCK,
        pad_USER_SPI_D_io => pad_USER_SPI_D,
        pad_FPGA_CFG_FCS2_B_o => pad_FPGA_CFG_FCS2_B,
        pad_FPGA_CFG_D_io => pad_FPGA_CFG_D
    );

    pad_USER_SPI_D <= (others => 'Z');
    pad_FPGA_CFG_D <= (others => 'Z');

    process
        procedure write_reg(
            reg : natural; value : reg_data_t; quiet : boolean := false) is
        begin
            write_reg(
                clk, write_data, write_strobe, write_ack, reg, value, quiet);
        end;

        procedure read_reg(reg : natural) is
        begin
            read_reg(clk, read_data, read_strobe, read_ack, reg);
        end;

    begin
        write_strobe <= (others => '0');
        read_strobe <= (others => '0');

        clk_wait(5);
        write_reg(FLASH_COMMAND_REG, (others => '0'));
        read_reg(FLASH_ADDRESS_REG);

        wait;
    end process;
end;
