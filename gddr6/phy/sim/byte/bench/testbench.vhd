library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use std.textio.all;

use work.support.all;

entity testbench is
end testbench;


architecture arch of testbench is
    constant BITSLICE_WANTED : std_ulogic_vector(0 to 11)
        := "111000011110";
    constant REFCLK_FREQUENCY : real := 2000.0;     -- 2 GHz ref clock

    signal pll_clk_in : std_ulogic := '0';  -- @ 250 MHz
    signal pll_clkfb : std_ulogic;
    signal clkoutphyen : std_ulogic;
    signal pll_reset : std_ulogic;
    signal pll_locked : std_ulogic;
    signal clkoutphy : std_ulogic;          -- @ 2 GHz
    signal tx_clk : std_ulogic;             -- @ 250 MHz
    signal rx_clk : std_ulogic;             -- @ 500 MHz

    signal fifo_rd_clk : std_ulogic := '0';
    signal reg_clk : std_ulogic := '0';
    signal fifo_empty : std_ulogic;
    signal fifo_enable : std_ulogic;
    signal nibble_reset : std_ulogic;
    signal enable_control_vtc : std_ulogic;
    signal enable_tri_vtc : std_ulogic_vector(0 to 1);
    signal enable_bitslice_vtc : std_ulogic_vector(0 to 11);
    signal dly_ready : std_ulogic;
    signal vtc_ready : std_ulogic;
    signal rx_load : std_ulogic_vector(0 to 11);
    signal rx_delay_in : std_ulogic_vector(8 downto 0);
    signal rx_delay_out : vector_array(0 to 11)(8 downto 0);
    signal tx_load : std_ulogic_vector(0 to 11);
    signal tx_delay_in : std_ulogic_vector(8 downto 0);
    signal tx_delay_out : vector_array(0 to 11)(8 downto 0);
    signal tri_load : std_ulogic_vector(0 to 1);
    signal tri_delay_in : std_ulogic_vector(8 downto 0);
    signal tri_delay_out : vector_array(0 to 1)(8 downto 0);
    signal pad_in : std_ulogic_vector(0 to 11);
    signal data_in : vector_array(0 to 11)(7 downto 0);
    signal data_out : vector_array(0 to 11)(7 downto 0);
    signal pad_out : std_ulogic_vector(0 to 11);
    signal tbyte : std_ulogic_vector(3 downto 0);
    signal pad_t_out : std_ulogic_vector(0 to 11);
    signal clk_to_north : std_ulogic;
    signal clk_to_south : std_ulogic;

    procedure write(message : string) is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

begin
    pll_clk_in <= not pll_clk_in after 2 ns;
--     fifo_rd_clk <= not fifo_rd_clk after 2 ns;
    reg_clk <= not reg_clk after 5 ns;

    byte : entity work.gddr6_phy_byte generic map (
        BITSLICE_WANTED => BITSLICE_WANTED,
        REFCLK_FREQUENCY => REFCLK_FREQUENCY,

        CLK_FROM_PIN => true,
        CLK_TO_NORTH => true,
        CLK_TO_SOUTH => true
    ) port map (
        pll_clk_i => clkoutphy,
        fifo_rd_clk_i => fifo_rd_clk,
        reg_clk_i => reg_clk,

        fifo_empty_o => fifo_empty,
        fifo_enable_i => fifo_enable,

        reset_i => nibble_reset,
        enable_control_vtc_i => enable_control_vtc,
        enable_tri_vtc_i => enable_tri_vtc,
        enable_bitslice_vtc_i => enable_bitslice_vtc,
        dly_ready_o => dly_ready,
        vtc_ready_o => vtc_ready,

        rx_load_i => rx_load,
        rx_delay_i => rx_delay_in,
        rx_delay_o => rx_delay_out,
        tx_load_i => tx_load,
        tx_delay_i => tx_delay_in,
        tx_delay_o => tx_delay_out,
        tri_load_i => tri_load,
        tri_delay_i => tri_delay_in,
        tri_delay_o => tri_delay_out,

        data_o => data_in,
        data_i => data_out,
        tbyte_i => tbyte,

        pad_in_i => pad_in,
        pad_out_o => pad_out,
        pad_t_out_o => pad_t_out,

        clk_from_ext_i => '1',
        clk_to_north_o => clk_to_north,
        clk_to_south_o => clk_to_south
    );


    pll : plle3_adv generic map (
        CLKFBOUT_MULT => 4,
        CLKFBOUT_PHASE => 0.0,
        CLKIN_PERIOD => 4.0,        -- 250 MHz clock in
        CLKOUT0_DIVIDE => 4,        -- 1/8 of reference clock on clkoutphy
        CLKOUT1_DIVIDE => 2,        -- 1/4 of reference for input clock
        CLKOUTPHY_MODE => "VCO_2X",
        DIVCLK_DIVIDE => 1,
        COMPENSATION => "AUTO",
        IS_CLKFBIN_INVERTED => '0',
        IS_CLKIN_INVERTED => '0',
        IS_PWRDWN_INVERTED => '0',
        IS_RST_INVERTED => '0',
        REF_JITTER => 0.0,
        STARTUP_WAIT => "FALSE"
    ) port map (
        CLKFBOUT => pll_clkfb,
        CLKOUT0 => tx_clk,
        CLKOUT0B => open,
        CLKOUT1 => rx_clk,
        CLKOUT1B => open,
        PWRDWN => '0',
        CLKFBIN => pll_clkfb,
        DADDR => B"0000000",
        DCLK => '0',
        DEN => '0',
        DWE => '0',
        DI => X"0000",
        DO => open,
        DRDY => open,
        RST => pll_reset,
        LOCKED => pll_locked,
        CLKIN => pll_clk_in,
        CLKOUTPHY => clkoutphy,
        CLKOUTPHYEN => clkoutphyen
    );


    fifo_enable <= '1';

    tbyte <= "0000";

    pad_in <= (
        0 => rx_clk,
        1 => pad_out(1),
        2 => pad_out(2),
        others => '0'
    );

    fifo_rd_clk <= tx_clk;

    process begin
        pll_reset <= '1';
        clkoutphyen <= '0';
        nibble_reset <= '1';
        enable_control_vtc <= '0';

        data_out <= (others => X"00");

        wait for 20 ns;
        pll_reset <= '0';
        wait until pll_locked;
        report "PLL locked";

        wait for 4 ns;
        nibble_reset <= '0';

        wait for 64 * 4 ns;
        clkoutphyen <= '1';

        wait until dly_ready;
        report "Control ready";

        wait until rising_edge(reg_clk);
        wait until rising_edge(reg_clk);
        enable_control_vtc <= '1';

        wait until vtc_ready;
        report "VTC ready";

        for i in 0 to 100 loop
            wait until rising_edge(tx_clk);
            data_out(1) <= to_std_ulogic_vector_u(i, 8);
            data_out(2) <= to_std_ulogic_vector_u(i, 8);
        end loop;

        wait until rising_edge(tx_clk);
        data_out(1) <= X"00";
        wait until rising_edge(tx_clk);
        data_out(1) <= X"FF";
        wait until rising_edge(tx_clk);
        data_out(1) <= X"00";

        loop
            wait until rising_edge(tx_clk);
            data_out(1) <= X"05";
            data_out(2) <= X"05";
--             wait until rising_edge(tx_clk);
--             data_out(1) <= X"2A";
--             data_out(2) <= X"2A";
        end loop;


        wait;
    end process;


    -- Register read and write
    process
        procedure clk_wait(count : natural := 1) is
        begin
            for n in 1 to count loop
                wait until rising_edge(reg_clk);
            end loop;
        end;

        procedure read_delays is
        begin
            enable_bitslice_vtc <= (others => '0');
            clk_wait(10);
            enable_bitslice_vtc <= (others => '1');
            clk_wait;
        end;

        procedure write_delay(
            slice : natural; rx_ntx : boolean; delay : natural) is
        begin
            enable_bitslice_vtc <= (others => '0');
            clk_wait(10);
            tx_delay_in <= to_std_ulogic_vector_u(delay, 9);
            rx_delay_in <= to_std_ulogic_vector_u(delay, 9);
            clk_wait;
            case rx_ntx is
                when true =>
                    rx_load(slice) <= '1';
                    clk_wait;
                    rx_load(slice) <= '0';
                when false =>
                    tx_load(slice) <= '1';
                    clk_wait;
                    tx_load(slice) <= '0';
            end case;
            clk_wait(10);
            enable_bitslice_vtc <= (others => '1');
            clk_wait;
        end;

    begin
        enable_tri_vtc <= "11";
        enable_bitslice_vtc <= (others => '1');
        rx_load <= (others => '0');
        tx_load <= (others => '0');

        wait until vtc_ready;
        clk_wait(20);
        read_delays;

        clk_wait;
        write_delay(1, true, 123);
        write_delay(1, false, 45);

        read_delays;

        wait;
    end process;
end;
