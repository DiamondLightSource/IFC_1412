library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

architecture arch of top is
    constant CK_FREQUENCY : real := 250.0;

    -- Clocks and resets
    signal clk : std_ulogic;
    signal reset_n : std_ulogic;
    -- We need a separate PCIe Reset signal which is marked as asynchronous
    signal perst_n : std_ulogic;


    -- -------------------------------------------------------------------------
    -- Register interface

    -- Wiring from AXI-Lite master to register slave
    signal DSP_REGS_araddr : std_ulogic_vector(16 downto 0);     -- AR
    signal DSP_REGS_arprot : std_ulogic_vector(2 downto 0);
    signal DSP_REGS_arready : std_ulogic;
    signal DSP_REGS_arvalid : std_ulogic;
    signal DSP_REGS_rdata : std_ulogic_vector(31 downto 0);      -- R
    signal DSP_REGS_rresp : std_ulogic_vector(1 downto 0);
    signal DSP_REGS_rready : std_ulogic;
    signal DSP_REGS_rvalid : std_ulogic;
    signal DSP_REGS_awaddr : std_ulogic_vector(16 downto 0);     -- AW
    signal DSP_REGS_awprot : std_ulogic_vector(2 downto 0);
    signal DSP_REGS_awready : std_ulogic;
    signal DSP_REGS_awvalid : std_ulogic;
    signal DSP_REGS_wdata : std_ulogic_vector(31 downto 0);      -- W
    signal DSP_REGS_wstrb : std_ulogic_vector(3 downto 0);
    signal DSP_REGS_wready : std_ulogic;
    signal DSP_REGS_wvalid : std_ulogic;
    signal DSP_REGS_bresp : std_ulogic_vector(1 downto 0);
    signal DSP_REGS_bready : std_ulogic;                         -- B
    signal DSP_REGS_bvalid : std_ulogic;

    -- Internal register path from AXI conversion
    signal regs_write_strobe : std_ulogic;
    signal regs_write_address : unsigned(13 downto 0);
    signal regs_write_data : std_ulogic_vector(31 downto 0);
    signal regs_write_ack : std_ulogic;
    signal regs_read_strobe : std_ulogic;
    signal regs_read_address : unsigned(13 downto 0);
    signal regs_read_data : std_ulogic_vector(31 downto 0);
    signal regs_read_ack : std_ulogic;

begin
    -- Clocks and resets
    clocking : entity work.system_clocking port map (
        sysclk100MHz_p => pad_SYSCLK100_P,
        sysclk100MHz_n => pad_SYSCLK100_N,
        clk_o => clk,
        reset_n_o => reset_n,
        perst_n_o => perst_n
    );


    -- -------------------------------------------------------------------------
    -- Interconnect
    interconnect : entity work.interconnect_wrapper port map (
        -- Clocking and reset
        nCOLDRST => perst_n,

        -- PCIe MGT interface
        FCLKA_clk_p(0) => pad_MGT224_REFCLK_P,
        FCLKA_clk_n(0) => pad_MGT224_REFCLK_N,
        pcie_7x_mgt_0_rxn => pad_AMC_RX_7_4_N,
        pcie_7x_mgt_0_rxp => pad_AMC_RX_7_4_P,
        pcie_7x_mgt_0_txn => pad_AMC_TX_7_4_N,
        pcie_7x_mgt_0_txp => pad_AMC_TX_7_4_P,

        -- Register clock and AXI reset
        DSP_CLK => clk,
        DSP_RESETN => reset_n,

        -- AXI-Lite register master interface
        M_DSP_REGS_araddr => DSP_REGS_araddr,
        M_DSP_REGS_arprot => DSP_REGS_arprot,
        M_DSP_REGS_arready => DSP_REGS_arready,
        M_DSP_REGS_arvalid => DSP_REGS_arvalid,
        M_DSP_REGS_rdata => DSP_REGS_rdata,
        M_DSP_REGS_rresp => DSP_REGS_rresp,
        M_DSP_REGS_rready => DSP_REGS_rready,
        M_DSP_REGS_rvalid => DSP_REGS_rvalid,
        M_DSP_REGS_awaddr => DSP_REGS_awaddr,
        M_DSP_REGS_awprot => DSP_REGS_awprot,
        M_DSP_REGS_awready => DSP_REGS_awready,
        M_DSP_REGS_awvalid => DSP_REGS_awvalid,
        M_DSP_REGS_wdata => DSP_REGS_wdata,
        M_DSP_REGS_wstrb => DSP_REGS_wstrb,
        M_DSP_REGS_wready => DSP_REGS_wready,
        M_DSP_REGS_wvalid => DSP_REGS_wvalid,
        M_DSP_REGS_bresp => DSP_REGS_bresp,
        M_DSP_REGS_bready => DSP_REGS_bready,
        M_DSP_REGS_bvalid => DSP_REGS_bvalid
    );


    -- -------------------------------------------------------------------------
    -- Register control

    -- AXI-lite slave to register interface
    axi_lite_slave : entity work.axi_lite_slave port map (
        clk_i => clk,
        rstn_i => reset_n,

        -- AXI-Lite read interface
        araddr_i => DSP_REGS_araddr(15 downto 0),
        arprot_i => DSP_REGS_arprot,
        arvalid_i => DSP_REGS_arvalid,
        arready_o => DSP_REGS_arready,
        rdata_o => DSP_REGS_rdata,
        rresp_o => DSP_REGS_rresp,
        rvalid_o => DSP_REGS_rvalid,
        rready_i => DSP_REGS_rready,

        -- AXI-Lite write interface
        awaddr_i => DSP_REGS_awaddr(15 downto 0),
        awprot_i => DSP_REGS_awprot,
        awvalid_i => DSP_REGS_awvalid,
        awready_o => DSP_REGS_awready,
        wdata_i => DSP_REGS_wdata,
        wstrb_i => DSP_REGS_wstrb,
        wvalid_i => DSP_REGS_wvalid,
        wready_o => DSP_REGS_wready,
        bready_i => DSP_REGS_bready,
        bresp_o => DSP_REGS_bresp,
        bvalid_o => DSP_REGS_bvalid,

        -- Internal register interface
        read_strobe_o => regs_read_strobe,
        read_address_o => regs_read_address,
        read_data_i => regs_read_data,
        read_ack_i => regs_read_ack,
        write_strobe_o => regs_write_strobe,
        write_address_o => regs_write_address,
        write_data_o => regs_write_data,
        write_ack_i => regs_write_ack
    );


    test_gddr6_phy : entity work.test_gddr6_phy port map (
        clk_i => clk,

        regs_write_strobe_i => regs_write_strobe,
        regs_write_address_i => regs_write_address,
        regs_write_data_i => regs_write_data,
        regs_write_ack_o => regs_write_ack,
        regs_read_strobe_i => regs_read_strobe,
        regs_read_address_i => regs_read_address,
        regs_read_data_o => regs_read_data,
        regs_read_ack_o => regs_read_ack,

        pad_LMK_CTL_SEL_o => pad_LMK_CTL_SEL,
        pad_LMK_SCL_o => pad_LMK_SCL,
        pad_LMK_SCS_L_o => pad_LMK_SCS_L,
        pad_LMK_SDIO_io => pad_LMK_SDIO,
        pad_LMK_RESET_L_o => pad_LMK_RESET_L,
        pad_LMK_SYNC_io => pad_LMK_SYNC,
        pad_LMK_STATUS_io => pad_LMK_STATUS,

        pad_SG12_CK_P_i => pad_SG12_CK_P,
        pad_SG12_CK_N_i => pad_SG12_CK_N,
        pad_SG1_WCK_P_i => pad_SG1_WCK_P,
        pad_SG1_WCK_N_i => pad_SG1_WCK_N,
        pad_SG2_WCK_P_i => pad_SG2_WCK_P,
        pad_SG2_WCK_N_i => pad_SG2_WCK_N,
        pad_SG1_RESET_N_o => pad_SG1_RESET_N,
        pad_SG2_RESET_N_o => pad_SG2_RESET_N,
        pad_SG12_CKE_N_o => pad_SG12_CKE_N,
        pad_SG12_CAL_o => pad_SG12_CAL,
        pad_SG1_CA3_A_o => pad_SG1_CA3_A,
        pad_SG1_CA3_B_o => pad_SG1_CA3_B,
        pad_SG2_CA3_A_o => pad_SG2_CA3_A,
        pad_SG2_CA3_B_o => pad_SG2_CA3_B,
        pad_SG12_CAU_o => pad_SG12_CAU,
        pad_SG12_CABI_N_o => pad_SG12_CABI_N,
        pad_SG1_DQ_A_io => pad_SG1_DQ_A,
        pad_SG1_DQ_B_io => pad_SG1_DQ_B,
        pad_SG2_DQ_A_io => pad_SG2_DQ_A,
        pad_SG2_DQ_B_io => pad_SG2_DQ_B,
        pad_SG1_DBI_N_A_io => pad_SG1_DBI_N_A,
        pad_SG1_DBI_N_B_io => pad_SG1_DBI_N_B,
        pad_SG2_DBI_N_A_io => pad_SG2_DBI_N_A,
        pad_SG2_DBI_N_B_io => pad_SG2_DBI_N_B,
        pad_SG1_EDC_A_io => pad_SG1_EDC_A,
        pad_SG1_EDC_B_io => pad_SG1_EDC_B,
        pad_SG2_EDC_A_io => pad_SG2_EDC_A,
        pad_SG2_EDC_B_io => pad_SG2_EDC_B
    );


    -- Unconnected LEDs for the moment
    pad_FP_LED2A_K <= '0';
    pad_FP_LED2B_K <= '0';
    pad_FMC1_LED <= (others => '0');
    pad_FMC2_LED <= (others => '0');
end;
