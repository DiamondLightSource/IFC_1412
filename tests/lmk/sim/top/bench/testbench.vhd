library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity testbench is
end testbench;


architecture arch of testbench is
    signal pad_SYSCLK100_P : std_ulogic := '0';
    signal pad_SYSCLK100_N : std_ulogic := '1';
    signal pad_MGT224_REFCLK_P : std_ulogic := '0';
    signal pad_MGT224_REFCLK_N : std_ulogic := '1';
    signal pad_AMC_PCI_RX_P : std_ulogic_vector(7 downto 4);
    signal pad_AMC_PCI_RX_N : std_ulogic_vector(7 downto 4);
    signal pad_AMC_PCI_TX_P : std_ulogic_vector(7 downto 4);
    signal pad_AMC_PCI_TX_N : std_ulogic_vector(7 downto 4);
    signal pad_FP_LED2A_K : std_ulogic;
    signal pad_FP_LED2B_K : std_ulogic;
    signal pad_FMC1_LED : std_ulogic_vector(1 to 8);
    signal pad_FMC2_LED : std_ulogic_vector(1 to 8);
    signal pad_LMK_CTL_SEL : std_ulogic;
    signal pad_LMK_SCL : std_ulogic;
    signal pad_LMK_SCS_L : std_ulogic;
    signal pad_LMK_SDIO : std_logic;
    signal pad_LMK_RESET_L : std_ulogic;
    signal pad_LMK_SYNC : std_logic;
    signal pad_LMK_STATUS : std_logic_vector(0 to 1);
    signal pad_SG12_CK_P : std_ulogic;
    signal pad_SG12_CK_N : std_ulogic;
    signal pad_SG1_WCK_P : std_ulogic;
    signal pad_SG1_WCK_N : std_ulogic;
    signal pad_SG2_WCK_P : std_ulogic;
    signal pad_SG2_WCK_N : std_ulogic;
    signal pad_FPGA_ACQCLK_P : std_ulogic;
    signal pad_FPGA_ACQCLK_N : std_ulogic;
    signal pad_AMC_TCLKB_IN_P : std_ulogic;
    signal pad_AMC_TCLKB_IN_N : std_ulogic;
    signal pad_E10G_CLK1_P : std_ulogic;
    signal pad_E10G_CLK1_N : std_ulogic;
    signal pad_E10G_CLK2_P : std_ulogic;
    signal pad_E10G_CLK2_N : std_ulogic;
    signal pad_E10G_CLK3_P : std_ulogic;
    signal pad_E10G_CLK3_N : std_ulogic;
    signal pad_MGT126_CLK0_P : std_ulogic;
    signal pad_MGT126_CLK0_N : std_ulogic;
    signal pad_MGT227_REFCLK_P : std_ulogic;
    signal pad_MGT227_REFCLK_N : std_ulogic;
    signal pad_MGT229_REFCLK_P : std_ulogic;
    signal pad_MGT229_REFCLK_N : std_ulogic;
    signal pad_MGT230_REFCLK_P : std_ulogic;
    signal pad_MGT230_REFCLK_N : std_ulogic;
    signal pad_MGT127_REFCLK_P : std_ulogic;
    signal pad_MGT127_REFCLK_N : std_ulogic;
    signal pad_MGT232_REFCLK_P : std_ulogic;
    signal pad_MGT232_REFCLK_N : std_ulogic;
    signal pad_RTM_GTP_CLK0_IN_P : std_ulogic;
    signal pad_RTM_GTP_CLK0_IN_N : std_ulogic;
    signal pad_RTM_GTP_CLK3_IN_P : std_ulogic;
    signal pad_RTM_GTP_CLK3_IN_N : std_ulogic;
    signal pad_FMC1_CLK_P : std_logic_vector(0 to 3);
    signal pad_FMC1_CLK_N : std_logic_vector(0 to 3);
    signal pad_FMC2_CLK_P : std_logic_vector(0 to 3);
    signal pad_FMC2_CLK_N : std_logic_vector(0 to 3);
    signal pad_FMC1_GBTCLK_P : std_ulogic_vector(0 to 3);
    signal pad_FMC1_GBTCLK_N : std_ulogic_vector(0 to 3);
    signal pad_FMC2_GBTCLK_P : std_ulogic_vector(0 to 3);
    signal pad_FMC2_GBTCLK_N : std_ulogic_vector(0 to 3);

begin
    pad_SYSCLK100_P <= not pad_SYSCLK100_P after 5 ns;
    pad_SYSCLK100_N <= not pad_SYSCLK100_P;
    pad_MGT224_REFCLK_P <= pad_SYSCLK100_P;
    pad_MGT224_REFCLK_N <= pad_SYSCLK100_N;

    top : entity work.top port map (
        pad_SYSCLK100_P => pad_SYSCLK100_P,
        pad_SYSCLK100_N => pad_SYSCLK100_N,
        pad_MGT224_REFCLK_P => pad_MGT224_REFCLK_P,
        pad_MGT224_REFCLK_N => pad_MGT224_REFCLK_N,
        pad_AMC_PCI_RX_P => pad_AMC_PCI_RX_P,
        pad_AMC_PCI_RX_N => pad_AMC_PCI_RX_N,
        pad_AMC_PCI_TX_P => pad_AMC_PCI_TX_P,
        pad_AMC_PCI_TX_N => pad_AMC_PCI_TX_N,
        pad_FP_LED2A_K => pad_FP_LED2A_K,
        pad_FP_LED2B_K => pad_FP_LED2B_K,
        pad_FMC1_LED => pad_FMC1_LED,
        pad_FMC2_LED => pad_FMC2_LED,
        pad_LMK_CTL_SEL => pad_LMK_CTL_SEL,
        pad_LMK_SCL => pad_LMK_SCL,
        pad_LMK_SCS_L => pad_LMK_SCS_L,
        pad_LMK_SDIO => pad_LMK_SDIO,
        pad_LMK_RESET_L => pad_LMK_RESET_L,
        pad_LMK_SYNC => pad_LMK_SYNC,
        pad_LMK_STATUS => pad_LMK_STATUS,
        pad_SG12_CK_P => pad_SG12_CK_P,
        pad_SG12_CK_N => pad_SG12_CK_N,
        pad_SG1_WCK_P => pad_SG1_WCK_P,
        pad_SG1_WCK_N => pad_SG1_WCK_N,
        pad_SG2_WCK_P => pad_SG2_WCK_P,
        pad_SG2_WCK_N => pad_SG2_WCK_N,
        pad_FPGA_ACQCLK_P => pad_FPGA_ACQCLK_P,
        pad_FPGA_ACQCLK_N => pad_FPGA_ACQCLK_N,
        pad_AMC_TCLKB_IN_P => pad_AMC_TCLKB_IN_P,
        pad_AMC_TCLKB_IN_N => pad_AMC_TCLKB_IN_N,
        pad_E10G_CLK1_P => pad_E10G_CLK1_P,
        pad_E10G_CLK1_N => pad_E10G_CLK1_N,
        pad_E10G_CLK2_P => pad_E10G_CLK2_P,
        pad_E10G_CLK2_N => pad_E10G_CLK2_N,
        pad_E10G_CLK3_P => pad_E10G_CLK3_P,
        pad_E10G_CLK3_N => pad_E10G_CLK3_N,
        pad_MGT126_CLK0_P => pad_MGT126_CLK0_P,
        pad_MGT126_CLK0_N => pad_MGT126_CLK0_N,
        pad_MGT227_REFCLK_P => pad_MGT227_REFCLK_P,
        pad_MGT227_REFCLK_N => pad_MGT227_REFCLK_N,
        pad_MGT229_REFCLK_P => pad_MGT229_REFCLK_P,
        pad_MGT229_REFCLK_N => pad_MGT229_REFCLK_N,
        pad_MGT230_REFCLK_P =>  pad_MGT230_REFCLK_P,
        pad_MGT230_REFCLK_N => pad_MGT230_REFCLK_N,
        pad_MGT127_REFCLK_P => pad_MGT127_REFCLK_P,
        pad_MGT127_REFCLK_N => pad_MGT127_REFCLK_N,
        pad_MGT232_REFCLK_P => pad_MGT232_REFCLK_P,
        pad_MGT232_REFCLK_N => pad_MGT232_REFCLK_N,
        pad_RTM_GTP_CLK0_IN_P => pad_RTM_GTP_CLK0_IN_P,
        pad_RTM_GTP_CLK0_IN_N => pad_RTM_GTP_CLK0_IN_N,
        pad_RTM_GTP_CLK3_IN_P => pad_RTM_GTP_CLK3_IN_P,
        pad_RTM_GTP_CLK3_IN_N => pad_RTM_GTP_CLK3_IN_N,
        pad_FMC1_CLK_P => pad_FMC1_CLK_P,
        pad_FMC1_CLK_N => pad_FMC1_CLK_N,
        pad_FMC2_CLK_P => pad_FMC2_CLK_P,
        pad_FMC2_CLK_N => pad_FMC2_CLK_N,
        pad_FMC1_GBTCLK_P => pad_FMC1_GBTCLK_P,
        pad_FMC1_GBTCLK_N => pad_FMC1_GBTCLK_N,
        pad_FMC2_GBTCLK_P => pad_FMC2_GBTCLK_P,
        pad_FMC2_GBTCLK_N => pad_FMC2_GBTCLK_N
    );

    pad_LMK_SDIO <= 'Z';
    pad_LMK_STATUS <= "ZZ";
end;
