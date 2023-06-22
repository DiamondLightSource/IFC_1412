library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;

use work.support.all;

entity testbench is
end testbench;

architecture arch of testbench is
    signal clk : std_ulogic := '0';

    procedure clk_wait(count : natural := 1) is
    begin
        for n in 1 to count loop
            wait until rising_edge(clk);
        end loop;
    end;

    signal command_select : std_ulogic;
    signal select_valid : std_ulogic;
    signal status : std_ulogic_vector(1 downto 0);
    signal reset : std_ulogic;
    signal sync : std_ulogic;

    signal write_strobe : std_ulogic;
    signal write_ack : std_ulogic;
    signal read_write_n : std_ulogic;
    signal address : std_ulogic_vector(14 downto 0);
    signal data_in : std_ulogic_vector(7 downto 0);
    signal write_select : std_ulogic;

    signal read_strobe : std_ulogic;
    signal read_ack : std_ulogic;
    signal data_out : std_ulogic_vector(7 downto 0);

    signal pad_LMK_CTL_SEL : std_ulogic;
    signal pad_LMK_SCL : std_ulogic;
    signal pad_LMK_SCS_L : std_ulogic;
    signal pad_LMK_SDIO : std_logic;
    signal pad_LMK_RESET_L : std_ulogic;
    signal pad_LMK_SYNC : std_logic;
    signal pad_LMK_STATUS : std_logic_vector(1 downto 0);

    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

begin
    -- 250 MHz clock
    clk <= not clk after 2 ns;

    lmk : entity work.lmk04616 port map (
        clk_i => clk,

        command_select_i => command_select,
        select_valid_o => select_valid,
        status_o => status,
        reset_i => reset,
        sync_i => sync,

        write_strobe_i => write_strobe,
        write_ack_o => write_ack,
        read_write_n_i => read_write_n,
        address_i => address,
        data_i => data_in,
        write_select_i => write_select,

        read_strobe_i => read_strobe,
        read_ack_o => read_ack,
        data_o => data_out,

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
        procedure do_spi(
            sel : std_ulogic; r_wn : std_ulogic;
            addr : std_ulogic_vector; data : std_ulogic_vector) is
        begin
            write_select <= sel;
            address <= addr;
            data_in <= data;
            read_write_n <= r_wn;
            write_strobe <= '1';
            clk_wait;
            write_strobe <= '0';
            while not write_ack loop
                clk_wait;
            end loop;
        end;

        procedure write_spi(
            sel : std_ulogic;
            addr : std_ulogic_vector; data : std_ulogic_vector) is
        begin
            do_spi(sel, '0', addr, data);
            write("SPI" & to_string(sel) & "[" & to_hstring(addr) &
                "] <= " & to_hstring(data));
        end;

        procedure read_spi(sel : std_ulogic; addr : std_ulogic_vector) is
        begin
            do_spi(sel, '1', addr, X"UU");
            read_strobe <= '1';
            clk_wait;
            read_strobe <= '0';
            while not read_ack loop
                clk_wait;
            end loop;
            write("SPI" & to_string(sel) & "[" & to_hstring(addr) &
                "] => " & to_hstring(data_out));
        end;

    begin
        command_select <= '0';
        reset <= '0';
        sync <= '0';

        write_strobe <= '0';
        read_strobe <= '0';

        clk_wait(5);

        write_spi('0', 15X"1234", X"34");
        write_spi('1', 15X"1234", X"12");
        read_spi('1', 15X"34");
        read_spi('0', 15X"34");

        wait;
    end process;
end;
