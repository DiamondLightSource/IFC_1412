library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity testbench is
end testbench;


architecture arch of testbench is
    signal pad_SYSCLK100_P : std_ulogic := '0';
    signal pad_SYSCLK100_N : std_ulogic;
    signal pad_MGT224_REFCLK_P : std_ulogic := '0';
    signal pad_MGT224_REFCLK_N : std_ulogic;
    signal pad_AMC_RX_7_4_P : std_ulogic_vector(7 downto 4);
    signal pad_AMC_RX_7_4_N : std_ulogic_vector(7 downto 4);
    signal pad_AMC_TX_7_4_P : std_ulogic_vector(7 downto 4);
    signal pad_AMC_TX_7_4_N : std_ulogic_vector(7 downto 4);
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
    signal pad_SG12_CKE_N : std_ulogic;
    signal pad_SG12_CAL : std_ulogic_vector(2 downto 0);
    signal pad_SG1_CA3_A : std_ulogic;
    signal pad_SG1_CA3_B : std_ulogic;
    signal pad_SG2_CA3_A : std_ulogic;
    signal pad_SG2_CA3_B : std_ulogic;
    signal pad_SG12_CAU : std_ulogic_vector(9 downto 4);
    signal pad_SG12_CABI_N : std_ulogic;
    signal pad_SG1_DQ_A : std_logic_vector(15 downto 0);
    signal pad_SG1_DQ_B : std_logic_vector(15 downto 0);
    signal pad_SG2_DQ_A : std_logic_vector(15 downto 0);
    signal pad_SG2_DQ_B : std_logic_vector(15 downto 0);
    signal pad_SG1_DBI_N_A : std_logic_vector(1 downto 0);
    signal pad_SG1_DBI_N_B : std_logic_vector(1 downto 0);
    signal pad_SG2_DBI_N_A : std_logic_vector(1 downto 0);
    signal pad_SG2_DBI_N_B : std_logic_vector(1 downto 0);
    signal pad_SG1_EDC_A : std_logic_vector(1 downto 0);
    signal pad_SG1_EDC_B : std_logic_vector(1 downto 0);
    signal pad_SG2_EDC_A : std_logic_vector(1 downto 0);
    signal pad_SG2_EDC_B : std_logic_vector(1 downto 0);
    signal pad_SG1_RESET_N : std_ulogic;
    signal pad_SG2_RESET_N : std_ulogic;

begin
    -- Run the two 100 MHz reference clocks
    pad_SYSCLK100_P <= not pad_SYSCLK100_P after 5 ns;
    pad_SYSCLK100_N <= not pad_SYSCLK100_P;
    pad_MGT224_REFCLK_P <= not pad_MGT224_REFCLK_P after 5 ns;
    pad_MGT224_REFCLK_N <= not pad_MGT224_REFCLK_P;

    top : entity work.top port map (
        pad_SYSCLK100_P => pad_SYSCLK100_P,
        pad_SYSCLK100_N => pad_SYSCLK100_N,
        pad_MGT224_REFCLK_P => pad_MGT224_REFCLK_P,
        pad_MGT224_REFCLK_N => pad_MGT224_REFCLK_N,
        pad_AMC_RX_7_4_P => pad_AMC_RX_7_4_P,
        pad_AMC_RX_7_4_N => pad_AMC_RX_7_4_N,
        pad_AMC_TX_7_4_P => pad_AMC_TX_7_4_P,
        pad_AMC_TX_7_4_N => pad_AMC_TX_7_4_N,
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
        pad_SG12_CKE_N => pad_SG12_CKE_N,
        pad_SG12_CAL => pad_SG12_CAL,
        pad_SG1_CA3_A => pad_SG1_CA3_A,
        pad_SG1_CA3_B => pad_SG1_CA3_B,
        pad_SG2_CA3_A => pad_SG2_CA3_A,
        pad_SG2_CA3_B => pad_SG2_CA3_B,
        pad_SG12_CAU => pad_SG12_CAU,
        pad_SG12_CABI_N => pad_SG12_CABI_N,
        pad_SG1_DQ_A => pad_SG1_DQ_A,
        pad_SG1_DQ_B => pad_SG1_DQ_B,
        pad_SG2_DQ_A => pad_SG2_DQ_A,
        pad_SG2_DQ_B => pad_SG2_DQ_B,
        pad_SG1_DBI_N_A => pad_SG1_DBI_N_A,
        pad_SG1_DBI_N_B => pad_SG1_DBI_N_B,
        pad_SG2_DBI_N_A => pad_SG2_DBI_N_A,
        pad_SG2_DBI_N_B => pad_SG2_DBI_N_B,
        pad_SG1_EDC_A => pad_SG1_EDC_A,
        pad_SG1_EDC_B => pad_SG1_EDC_B,
        pad_SG2_EDC_A => pad_SG2_EDC_A,
        pad_SG2_EDC_B => pad_SG2_EDC_B,
        pad_SG1_RESET_N => pad_SG1_RESET_N,
        pad_SG2_RESET_N => pad_SG2_RESET_N
    );

    pad_LMK_SDIO <= 'Z';
    pad_LMK_STATUS <= "ZZ";
end;
