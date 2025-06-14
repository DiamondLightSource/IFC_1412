library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity testbench is
end testbench;


architecture arch of testbench is
    signal pad_SYSCLK100_P : std_ulogic := '0';
    signal pad_SYSCLK100_N : std_ulogic := '1';
    signal pad_MGT224_REFCLK_P : std_ulogic;
    signal pad_MGT224_REFCLK_N : std_ulogic;
    signal pad_AMC_PCI_RX_P : std_ulogic_vector(7 downto 4);
    signal pad_AMC_PCI_RX_N : std_ulogic_vector(7 downto 4);
    signal pad_AMC_PCI_TX_P : std_ulogic_vector(7 downto 4);
    signal pad_AMC_PCI_TX_N : std_ulogic_vector(7 downto 4);
    signal pad_FPGA_SLAVE_SCL : std_logic;
    signal pad_FPGA_SLAVE_SDA : std_logic;

begin
    pad_SYSCLK100_P <= not pad_SYSCLK100_P after 5 ns;
    pad_SYSCLK100_N <= not pad_SYSCLK100_N after 5 ns;

    top : entity work.top port map (
        pad_SYSCLK100_P => pad_SYSCLK100_P,
        pad_SYSCLK100_N => pad_SYSCLK100_N,
        pad_MGT224_REFCLK_P => pad_MGT224_REFCLK_P,
        pad_MGT224_REFCLK_N => pad_MGT224_REFCLK_N,
        pad_AMC_PCI_RX_P => pad_AMC_PCI_RX_P,
        pad_AMC_PCI_RX_N => pad_AMC_PCI_RX_N,
        pad_AMC_PCI_TX_P => pad_AMC_PCI_TX_P,
        pad_AMC_PCI_TX_N => pad_AMC_PCI_TX_N,
        pad_FPGA_SLAVE_SCL => pad_FPGA_SLAVE_SCL,
        pad_FPGA_SLAVE_SDA => pad_FPGA_SLAVE_SDA
    );

    pad_FPGA_SLAVE_SCL <= 'H';
    pad_FPGA_SLAVE_SDA <= 'H';
end;
