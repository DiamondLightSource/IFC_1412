library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

architecture arch of top is
    signal sysclk_in : std_ulogic;
    signal clk : std_ulogic;

    signal reset_counter : unsigned(10 downto 0) := (others => '1');
    signal reset_active : std_ulogic := '1';

    signal led_counter : unsigned(25 downto 0) := (others => '0');
    signal led_a : std_ulogic := '1';   -- Green if low
    signal led_b : std_ulogic := '1';   -- Red if low

begin
    interconnect : entity work.interconnect_wrapper port map (
        -- Clocking and reset
        nCOLDRST => not reset_active,
        -- PCIe MGT interface
        FCLKA_clk_p(0) => pad_MGT224_REFCLK_P,
        FCLKA_clk_n(0) => pad_MGT224_REFCLK_N,
        pcie_7x_mgt_0_rxn => pad_AMC_RX_7_4_N,
        pcie_7x_mgt_0_rxp => pad_AMC_RX_7_4_P,
        pcie_7x_mgt_0_txn => pad_AMC_TX_7_4_N,
        pcie_7x_mgt_0_txp => pad_AMC_TX_7_4_P
    );

    sysclk_ibuf : IBUFDS port map (
        I => pad_SYSCLK100_P,
        IB => pad_SYSCLK100_N,
        O => sysclk_in
    );

    clk_bufg : BUFG port map (
        I => sysclk_in,
        O => clk
    );

    -- Create reset
    process (clk) begin
        if rising_edge(clk) then
            if reset_active then
                if reset_counter > 0 then
                    reset_counter <= reset_counter - 1;
                else
                    reset_active <= '0';
                    led_a <= '0';
                end if;
            end if;

            led_counter <= led_counter + 1;
            if led_counter = 0 then
                led_b <= not led_b;
            end if;
        end if;
    end process;

    pad_FP_LED2A_K <= led_a;
    pad_FP_LED2B_K <= led_b;
end;
