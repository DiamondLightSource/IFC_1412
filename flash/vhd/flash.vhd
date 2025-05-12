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
        pad_USER_SPI_D_io : inout std_logic_vector(3 downto 0);
        -- FPGA configuration
        pad_FPGA_CFG_FCS2_B_o : out std_ulogic;
        pad_FPGA_CFG_D_io : inout std_logic_vector(7 downto 4)
    );
end;

architecture arch of flash is
    -- Both the MI and MO FIFOs need to have 8 bits of addressing (256 words, or
    -- 1024 bytes) to match the 10 bit transaction length.
    constant FIFO_BITS : natural := 8;

    -- Control to core
    signal select_spi : std_ulogic_vector(1 downto 0);
    signal read_delay : unsigned(2 downto 0);
    signal clock_speed : unsigned(1 downto 0);
    signal long_cs_high : std_ulogic;

    signal read_enable : std_ulogic;

    signal core_start : std_ulogic;
    signal core_next : std_ulogic;
    signal core_last : std_ulogic;
    signal core_busy : std_ulogic;

    -- MO data
    signal fifo_mo_data : std_ulogic_vector(7 downto 0);

    -- MI data
    signal fifo_mi_data : std_ulogic_vector(7 downto 0);
    signal fifo_mi_valid : std_ulogic;
    signal fifo_mi_last : std_ulogic;

    -- From core to IO
    signal spi_clk : std_ulogic;
    signal spi_cs_n : std_ulogic;
    signal spi_mosi : std_ulogic;
    signal spi_miso : std_ulogic;

begin
    control : entity work.flash_control port map (
        clk_i => clk_i,

        write_strobe_i => write_strobe_i(FLASH_COMMAND_REG),
        write_data_i => write_data_i(FLASH_COMMAND_REG),
        write_ack_o => write_ack_o(FLASH_COMMAND_REG),
        read_strobe_i => read_strobe_i(FLASH_COMMAND_REG),
        read_data_o => read_data_o(FLASH_COMMAND_REG),
        read_ack_o => read_ack_o(FLASH_COMMAND_REG),

        select_spi_o => select_spi,
        read_delay_o => read_delay,
        clock_speed_o => clock_speed,
        long_cs_high_o => long_cs_high,

        core_start_o => core_start,
        core_last_o => core_last,
        read_enable_o => read_enable,
        core_next_i => core_next,
        core_busy_i => core_busy
    );


    mo_fifo : entity work.flash_mo_fifo generic map (
        FIFO_BITS => FIFO_BITS
    ) port map (
        clk_i => clk_i,

        write_strobe_i => write_strobe_i(FLASH_DATA_REG),
        write_data_i => write_data_i(FLASH_DATA_REG),
        write_ack_o => write_ack_o(FLASH_DATA_REG),

        read_data_o => fifo_mo_data,
        read_ready_i => core_next and not core_last,
        read_reset_i => core_next and core_last
    );


    mi_fifo : entity work.flash_mi_fifo generic map (
        FIFO_BITS => FIFO_BITS
    ) port map (
        clk_i => clk_i,

        read_strobe_i => read_strobe_i(FLASH_DATA_REG),
        read_data_o => read_data_o(FLASH_DATA_REG),
        read_ack_o => read_ack_o(FLASH_DATA_REG),

        write_data_i => fifo_mi_data,
        write_valid_i => fifo_mi_valid,
        write_last_i => fifo_mi_last,
        write_reset_i => core_start
    );


    core : entity work.flash_spi_core port map (
        clk_i => clk_i,

        spi_clk_o => spi_clk,
        spi_cs_n_o => spi_cs_n,
        spi_mosi_o => spi_mosi,
        spi_miso_i => spi_miso,

        read_delay_i => read_delay,
        clock_speed_i => clock_speed,
        long_cs_high_i => long_cs_high,

        data_mo_i => fifo_mo_data,
        data_mi_o => fifo_mi_data,
        data_mi_valid_o => fifo_mi_valid,
        data_mi_last_o => fifo_mi_last,

        start_i => core_start,
        last_i => core_last,
        read_enable_i => read_enable,
        next_o => core_next,
        busy_o => core_busy
    );


    io : entity work.flash_io port map (
        clk_i => clk_i,

        pad_USER_SPI_CS_L_o => pad_USER_SPI_CS_L_o,
        pad_USER_SPI_SCK_o => pad_USER_SPI_SCK_o,
        pad_USER_SPI_D_io => pad_USER_SPI_D_io,
        pad_FPGA_CFG_FCS2_B_o => pad_FPGA_CFG_FCS2_B_o,
        pad_FPGA_CFG_D_io => pad_FPGA_CFG_D_io,

        select_i => select_spi,
        spi_clk_i => spi_clk,
        spi_cs_n_i => spi_cs_n,
        mosi_i => spi_mosi,
        miso_o => spi_miso
    );
end;
