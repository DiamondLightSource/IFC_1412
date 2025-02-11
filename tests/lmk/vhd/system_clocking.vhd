-- System clock and reset management

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.support.all;

entity system_clocking is
    port (
        -- External ports
        -- 100 MHz reference clock from copy of AMC FCLKA
        sysclk100MHz_p : in std_ulogic;
        sysclk100MHz_n : in std_ulogic;

        -- Control outputs
        clk_o : out std_ulogic;             -- General fabric clock @ 250 MHz
        reset_n_o : out std_ulogic;         -- Reset synchronous with clk
        perst_n_o : out std_ulogic          -- Reset for PCIe
    );
end;

architecture arch of system_clocking is
    -- Clocking from 100 MHz to fabric clock
    signal sysclk_in : std_ulogic;
    signal ref_pll_feedback : std_ulogic;
    signal ref_pll_locked : std_ulogic;
    signal clk_pll_out : std_ulogic;
    -- Generated clock
    signal clk : std_ulogic;

    -- Reset generation.  We need to generate our own reset, so we do this by
    -- counting down
    signal reset_counter : unsigned(10 downto 0) := (others => '1');
    signal reset_n_out : std_ulogic := '0';

    -- We need a separate PCIe Reset signal which is marked as asynchronous in
    -- constraints file.  Must ensure it keeps its name!
    signal perst_n_out : std_ulogic := '0';
    attribute KEEP : string;
    attribute KEEP of perst_n_out : signal is "true";

begin
    -- Use PLL to generate 250 MHz fallback clock from 100 MHz reference

    sysclk_ibuf : IBUFDS port map (
        I => sysclk100MHz_p,
        IB => sysclk100MHz_n,
        O => sysclk_in
    );

    -- PLL VCO must run in range 600 to 1200 MHz
    ref_pll : PLLE3_BASE generic map (
        CLKIN_PERIOD => 10.0,       -- 10 ns period for 100 MHz input clock
        CLKFBOUT_MULT => 10,        -- Run PLL at 1000 MHz
        CLKOUT0_DIVIDE => 4         -- Output clock at 250 MHz
    ) port map (
        -- Inputs
        CLKIN => sysclk_in,
        CLKFBIN => ref_pll_feedback,
        RST => '0',
        PWRDWN => '0',
        CLKOUTPHYEN => '0',
        -- Outputs
        CLKOUT0 => clk_pll_out,
        CLKFBOUT => ref_pll_feedback,
        LOCKED => ref_pll_locked
    );

    -- System clock out
    clk_bufg : BUFG port map (
        I => clk_pll_out,
        O => clk
    );
    clk_o <= clk;


    -- Create reset
    process (clk) begin
        if rising_edge(clk) then
            if reset_counter > 0 then
                reset_counter <= reset_counter - 1;
            end if;

            -- Need separate signals for these two resets to work around
            -- timing issues
            reset_n_out <= to_std_ulogic(reset_counter = 0);
            perst_n_out <= to_std_ulogic(reset_counter = 0);
        end if;
    end process;

    reset_n_o <= reset_n_out;
    perst_n_o <= perst_n_out;
end;
