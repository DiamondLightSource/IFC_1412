library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;

use work.support.all;
use work.register_defs.all;
use work.lmk04616_defines.all;
use work.sim_support.all;

entity testbench is
end testbench;

architecture arch of testbench is
    signal clk : std_ulogic := '0';

    procedure clk_wait(count : natural := 1) is
    begin
        clk_wait(clk, count);
    end;

    -- Register interface
    signal write_strobe : std_ulogic;
    signal write_data : reg_data_t;
    signal write_ack : std_ulogic;
    signal read_strobe : std_ulogic;
    signal read_data : reg_data_t;
    signal read_ack : std_ulogic;

    -- Connection to simulation
    signal pad_LMK_CTL_SEL : std_ulogic;
    signal pad_LMK_SCL : std_ulogic;
    signal pad_LMK_SCS_L : std_ulogic;
    signal pad_LMK_SDIO : std_logic;
    signal pad_LMK_RESET_L : std_ulogic;
    signal pad_LMK_SYNC : std_logic;
    signal pad_LMK_STATUS : std_logic_vector(1 downto 0);

begin
    -- 250 MHz clock
    clk <= not clk after 2 ns;

    lmk : entity work.lmk04616 generic map (
        STATUS_POLL_BITS => 6
    ) port map (
        clk_i => clk,

        -- Register interface
        write_strobe_i => write_strobe,
        write_data_i => write_data,
        write_ack_o => write_ack,
        read_strobe_i => read_strobe,
        read_data_o => read_data,
        read_ack_o => read_ack,

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


    process
        variable enable_status : std_ulogic := '0';

        procedure write_reg(value : reg_data_t) is
        begin
            write_reg(clk, write_data, write_strobe, write_ack, value);
        end;

        procedure read_reg is
        begin
            read_reg(clk, read_data, read_strobe, read_ack);
        end;

        procedure set_status(enable : std_ulogic) is
        begin
            enable_status := enable;
            write_reg((
                LMK04616_ENABLE_STATUS_BIT => enable_status,
                others => '0'));
        end;

        procedure do_spi(
            sel : std_ulogic; r_wn : std_ulogic;
            addr : std_ulogic_vector; data : std_ulogic_vector) is
        begin
            write_reg((
                LMK04616_DATA_BITS => data,
                LMK04616_ADDRESS_BITS => addr,
                LMK04616_R_WN_BIT => r_wn,
                LMK04616_SELECT_BIT => sel,
                LMK04616_ENABLE_BIT => '1',
                LMK04616_ENABLE_STATUS_BIT => enable_status,
                others => '0'));
        end;

        procedure write_spi(
            sel : std_ulogic;
            addr : std_ulogic_vector; data : std_ulogic_vector) is
        begin
            write("SPI" & to_string(sel) & "[" & to_hstring(addr) & "] <= " &
                to_hstring(data));
            do_spi(sel, '0', addr, data);
        end;

        procedure read_spi(sel : std_ulogic; addr : std_ulogic_vector) is
        begin
            do_spi(sel, '1', addr, X"UU");
            read_reg;
            write("SPI" & to_string(sel) & "[" & to_hstring(addr) & "] => " &
                to_hstring(read_data(LMK04616_DATA_BITS)));
        end;

    begin
        write_strobe <= '0';
        read_strobe <= '0';

        clk_wait(5);
        set_status('1');
        write_spi('0', 15X"1234", X"34");
        write_spi('1', 15X"1234", X"12");
        read_spi('1', 15X"34");
        read_spi('0', 15X"34");

        wait;
    end process;
end;
