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
    -- We need a separate PCIe Reset signal which is marked as asynchronous
    signal perst : std_ulogic := '1';
    attribute KEEP : string;
    attribute KEEP of perst : signal is "true";

    signal led_counter : unsigned(25 downto 0) := (others => '0');
    signal led_a : std_ulogic := '1';   -- Green if low
    signal led_b : std_ulogic := '1';   -- Red if low

begin
    interconnect : entity work.interconnect_wrapper port map (
        -- Clocking and reset
        nCOLDRST => not reset_active,
        PERSTN => not perst,
        -- PCIe MGT interface
        FCLKA_clk_p(0) => pad_MGT224_REFCLK_P,
        FCLKA_clk_n(0) => pad_MGT224_REFCLK_N,
        pcie_7x_mgt_0_rxn => pad_AMC_PCI_RX_N,
        pcie_7x_mgt_0_rxp => pad_AMC_PCI_RX_P,
        pcie_7x_mgt_0_txn => pad_AMC_PCI_TX_N,
        pcie_7x_mgt_0_txp => pad_AMC_PCI_TX_P,
        -- USER QSPI flash interface
        EXT_SPI_CLK => clk,
        USER_SPI_io0_io => pad_USER_SPI_D(0),
        USER_SPI_io1_io => pad_USER_SPI_D(1),
        USER_SPI_io2_io => pad_USER_SPI_D(2),
        USER_SPI_io3_io => pad_USER_SPI_D(3),
        USER_SPI_sck_io => pad_USER_SPI_SCK,
        USER_SPI_ss_io(0) => pad_USER_SPI_CS_L
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
                    perst <= '0';
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
