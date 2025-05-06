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

        type select_t is (NONE, USER, FPGA1, FPGA2);
        function to_std_ulogic_vector(selection : select_t)
            return std_ulogic_vector is
        begin
            case selection is
                when NONE => return "00";
                when USER => return "01";
                when FPGA1 => return "10";
                when FPGA2 => return "11";
            end case;
        end;

        procedure write_command(
            selection : select_t; length : natural;
            read_offset : natural := 1023;
            read_delay : natural := 0;
            clock_speed : unsigned(1 downto 0) := "01";
            long_cs_high : std_ulogic := '0') is
        begin
            write_reg(FLASH_COMMAND_REG, (
                FLASH_COMMAND_LENGTH_BITS =>
                    to_std_ulogic_vector_u(length, 10),
                FLASH_COMMAND_READ_OFFSET_BITS =>
                    to_std_ulogic_vector_u(read_offset, 10),
                FLASH_COMMAND_SELECT_BITS =>
                    to_std_ulogic_vector(selection),
                FLASH_COMMAND_READ_DELAY_BITS =>
                    to_std_ulogic_vector_u(read_delay, 3),
                FLASH_COMMAND_CLOCK_SPEED_BITS =>
                    std_ulogic_vector(clock_speed),
                FLASH_COMMAND_LONG_CS_HIGH_BIT => long_cs_high,
                others => '0'));
        end;

    begin
        write_strobe <= (others => '0');
        read_strobe <= (others => '0');

        -- Need to wait a bit for the IO startup to complete
        clk_wait(20);

--         write_reg(FLASH_DATA_REG, X"FF_FF_FF_5A");
--         clk_wait;
--         write_command(USER, 0, long_cs_high => '1');
-- 
--         write_reg(FLASH_DATA_REG, X"04_55_AA_00");
--         write_reg(FLASH_DATA_REG, X"08_07_06_05");
--         write_command(USER, 2,
--             read_offset => 0, clock_speed => "10", read_delay => 2);
-- 
--         clk_wait;
--         read_reg(FLASH_DATA_REG);

        -- Try a really fast read
        write_reg(FLASH_DATA_REG, X"FF_FF_53_11");
        write_command(USER, 1,
            read_offset => 0, clock_speed => "00", read_delay => 0);
        clk_wait(6);
        read_reg(FLASH_DATA_REG);

        -- Same with longer delay
        write_reg(FLASH_DATA_REG, X"FF_FF_12_11");
        write_command(USER, 1,
            read_offset => 0, clock_speed => "00", read_delay => 1);
        clk_wait(6);
        read_reg(FLASH_DATA_REG);

        -- Followed by a really slow one
        write_reg(FLASH_DATA_REG, X"FF_FF_AC_88");
        write_command(USER, 1,
            read_offset => 0, clock_speed => "11", read_delay => 0);
        clk_wait(6);
        read_reg(FLASH_DATA_REG);

        -- Followed by a really slow one
        write_reg(FLASH_DATA_REG, X"FF_FF_AC_88");
        write_command(USER, 1,
            read_offset => 0, clock_speed => "11", read_delay => 7);
        clk_wait(6);
        read_reg(FLASH_DATA_REG);

        wait;
    end process;


    user_spi : entity work.sim_spi generic map (
        NAME => "USER",
        -- Most optimistic delay from falling edge out to data back
        READ_DELAY => 1.5 ns
    ) port map (
        clk_i => pad_USER_SPI_SCK,
        cs_i => pad_USER_SPI_CS_L,
        mosi_i => pad_USER_SPI_D(0),
        miso_o => pad_USER_SPI_D(1)
    );


    fpga2_spi : entity work.sim_spi generic map (
        NAME => "FPGA2",
        -- Reasonably pessimistic delay:
        --  From clk_i via STARTUPE3 to CLK out: 1 to 7.5 ns
        --  From falling edge to data valid: up to 14.5 ns
        --  From data valid on MI back via STARTUPE3: 0.5 to 3.5 ns
        --  Extra routing of 0.5ns
        READ_DELAY => 26 ns
    ) port map (
        -- The FPGA config clock is buried and only connected to the STARTUPE3
        -- primitive, so we have to find it like this!
        clk_i => << signal flash.io.fpga_clk : std_ulogic >>,
        cs_i => pad_FPGA_CFG_FCS2_B,
        mosi_i => pad_FPGA_CFG_D(4),
        miso_o => pad_FPGA_CFG_D(5)
    );
end;
