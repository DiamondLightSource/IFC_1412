library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;

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

    signal pad_LMK_CTL_SEL : std_ulogic;
    signal pad_LMK_SCL : std_ulogic;
    signal pad_LMK_SCS_L : std_ulogic;
    signal pad_LMK_SDIO : std_logic;
    signal pad_LMK_RESET_L : std_ulogic;
    signal pad_LMK_SYNC : std_logic;
    signal pad_LMK_STATUS : std_logic_vector(1 downto 0);

    -- Decoded register wiring
    signal top_write_strobe : std_ulogic_vector(TOP_REGS_RANGE);
    signal top_write_data : reg_data_array_t(TOP_REGS_RANGE);
    signal top_write_ack : std_ulogic_vector(TOP_REGS_RANGE);
    signal top_read_strobe : std_ulogic_vector(TOP_REGS_RANGE);
    signal top_read_data : reg_data_array_t(TOP_REGS_RANGE);
    signal top_read_ack : std_ulogic_vector(TOP_REGS_RANGE);

    -- LMK config and status
    signal lmk_command_select : std_ulogic;
    signal lmk_status : std_ulogic_vector(1 downto 0);
    signal lmk_reset : std_ulogic;

    -- SPI interface to LMK
    signal lmk_write_strobe : std_ulogic;
    signal lmk_write_ack : std_ulogic;
    signal lmk_read_write_n : std_ulogic;
    signal lmk_address : std_ulogic_vector(14 downto 0);
    signal lmk_data_in : std_ulogic_vector(7 downto 0);
    signal lmk_write_select : std_ulogic;
    signal lmk_read_strobe : std_ulogic;
    signal lmk_read_ack : std_ulogic;
    signal lmk_data_out : std_ulogic_vector(7 downto 0);

begin
    -- 250 MHz clock
    clk <= not clk after 2 ns;

    lmk : entity work.lmk04616 port map (
        clk_i => clk,

        command_select_i => lmk_command_select,
        select_valid_o => open,
        status_o => lmk_status,
        reset_i => lmk_reset,
        sync_i => '1',

        write_strobe_i => lmk_write_strobe,
        write_ack_o => lmk_write_ack,
        read_write_n_i => lmk_read_write_n,
        address_i => lmk_address,
        data_i => lmk_data_out,
        write_select_i => lmk_write_select,

        read_strobe_i => lmk_read_strobe,
        read_ack_o => lmk_read_ack,
        data_o => lmk_data_in,

        pad_LMK_CTL_SEL_o => pad_LMK_CTL_SEL,
        pad_LMK_SCL_o => pad_LMK_SCL,
        pad_LMK_SCS_L_o => pad_LMK_SCS_L,
        pad_LMK_SDIO_io => pad_LMK_SDIO,
        pad_LMK_RESET_L_o => pad_LMK_RESET_L,
        pad_LMK_SYNC_io => pad_LMK_SYNC,
        pad_LMK_STATUS_io => pad_LMK_STATUS
    );

    sim : entity work.sim_lmk04616 port map (
        pad_LMK_CTL_SEL_i => pad_LMK_CTL_SEL,
        pad_LMK_SCL_i => pad_LMK_SCL,
        pad_LMK_SCS_L_i => pad_LMK_SCS_L,
        pad_LMK_SDIO_io => pad_LMK_SDIO,
        pad_LMK_RESET_L_i => pad_LMK_RESET_L,
        pad_LMK_SYNC_io => pad_LMK_SYNC,
        pad_LMK_STATUS_io => pad_LMK_STATUS
    );

    registers : entity work.top_registers port map (
        clk_i => clk,

        write_strobe_i => top_write_strobe,
        write_data_i => top_write_data,
        write_ack_o => top_write_ack,
        read_strobe_i => top_read_strobe,
        read_data_o => top_read_data,
        read_ack_o => top_read_ack,

        lmk_command_select_o => lmk_command_select,
        lmk_status_i => lmk_status,
        lmk_reset_o => lmk_reset,

        lmk_write_strobe_o => lmk_write_strobe,
        lmk_write_ack_i => lmk_write_ack,
        lmk_read_write_n_o => lmk_read_write_n,
        lmk_address_o => lmk_address,
        lmk_data_o => lmk_data_out,
        lmk_write_select_o => lmk_write_select,
        lmk_read_strobe_o => lmk_read_strobe,
        lmk_read_ack_i => lmk_read_ack,
        lmk_data_i => lmk_data_in,

        clock_counts_i => (others => (others => '0')),
        clock_update_i => '0'
    );


    process
        procedure write_reg(reg : natural; value : reg_data_t) is
        begin
            write_reg(
                clk, top_write_data, top_write_strobe, top_write_ack,
                reg, value);
        end;

        procedure read_reg(reg : natural) is
        begin
            read_reg(
                clk, top_read_data, top_read_strobe, top_read_ack,
                reg);
        end;

        procedure do_spi(
            sel : std_ulogic; r_wn : std_ulogic;
            addr : std_ulogic_vector; data : std_ulogic_vector) is
        begin
            write_reg(TOP_LMK04616_REG, (
                TOP_LMK04616_DATA_BITS => data,
                TOP_LMK04616_ADDRESS_BITS => addr,
                TOP_LMK04616_R_WN_BIT => r_wn,
                TOP_LMK04616_SELECT_BIT => sel,
                others => '0'));
        end;

        procedure write_spi(
            sel : std_ulogic;
            addr : std_ulogic_vector; data : std_ulogic_vector) is
        begin
            do_spi(sel, '0', addr, data);
        end;

        procedure read_spi(sel : std_ulogic; addr : std_ulogic_vector) is
        begin
            do_spi(sel, '1', addr, X"UU");
            read_reg(TOP_LMK04616_REG);
        end;

    begin
        top_write_strobe <= (others => '0');
        top_read_strobe <= (others => '0');

        clk_wait;
        read_reg(TOP_GIT_VERSION_REG);

        write_spi('0', 15X"1234", X"34");
        write_spi('1', 15X"1234", X"12");
        read_spi('1', 15X"34");
        read_spi('0', 15X"34");

        wait;
    end process;
end;
