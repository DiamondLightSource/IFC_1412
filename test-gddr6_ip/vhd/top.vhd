library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;

architecture arch of top is
    constant CK_FREQUENCY : real := 250.0;

    -- Clocks and resets
    signal clk : std_ulogic;
    signal reset_n : std_ulogic;
    -- We need a separate PCIe Reset signal which is marked as asynchronous
    signal pci_reset_n : std_ulogic;


    -- -------------------------------------------------------------------------
    -- Wiring to Interconnect
    --
    -- There are some strange port definitions here, these declarations are
    -- meant to directly match the output from the IP Generator, which makes
    -- some very odd choices in certain places.

    -- M_DSP from AXI-Lite master
    signal M_DSP_REGS_araddr : std_logic_vector(16 downto 0);
    signal M_DSP_REGS_arprot : std_logic_vector(2 downto 0);
    signal M_DSP_REGS_arready : std_logic;
    signal M_DSP_REGS_arvalid : std_logic;
    signal M_DSP_REGS_awaddr : std_logic_vector(16 downto 0);
    signal M_DSP_REGS_awprot : std_logic_vector(2 downto 0);
    signal M_DSP_REGS_awready : std_logic;
    signal M_DSP_REGS_awvalid : std_logic;
    signal M_DSP_REGS_bready : std_logic;
    signal M_DSP_REGS_bresp : std_logic_vector(1 downto 0);
    signal M_DSP_REGS_bvalid : std_logic;
    signal M_DSP_REGS_rdata : std_logic_vector(31 downto 0);
    signal M_DSP_REGS_rready : std_logic;
    signal M_DSP_REGS_rresp : std_logic_vector(1 downto 0);
    signal M_DSP_REGS_rvalid : std_logic;
    signal M_DSP_REGS_wdata : std_logic_vector(31 downto 0);
    signal M_DSP_REGS_wready : std_logic;
    signal M_DSP_REGS_wstrb : std_logic_vector(3 downto 0);
    signal M_DSP_REGS_wvalid : std_logic;
    -- s_axi to SGRAM GDDR6 AXI slave
    signal s_axi_araddr : std_logic_vector(48 downto 0);
    signal s_axi_arburst : std_logic_vector(1 downto 0);
    signal s_axi_arcache : std_logic_vector(3 downto 0);
    signal s_axi_arid : std_logic_vector(0 to 0);
    signal s_axi_arlen : std_logic_vector(7 downto 0);
    signal s_axi_arlock : std_logic_vector(0 to 0);
    signal s_axi_arprot : std_logic_vector(2 downto 0);
    signal s_axi_arqos : std_logic_vector(3 downto 0);
    signal s_axi_arready : std_logic_vector(0 to 0);
    signal s_axi_arsize : std_logic_vector(2 downto 0);
    signal s_axi_arvalid : std_logic_vector(0 to 0);
    signal s_axi_awaddr : std_logic_vector(48 downto 0);
    signal s_axi_awburst : std_logic_vector(1 downto 0);
    signal s_axi_awcache : std_logic_vector(3 downto 0);
    signal s_axi_awid : std_logic_vector(0 to 0);
    signal s_axi_awlen : std_logic_vector(7 downto 0);
    signal s_axi_awlock : std_logic_vector(0 to 0);
    signal s_axi_awprot : std_logic_vector(2 downto 0);
    signal s_axi_awqos : std_logic_vector(3 downto 0);
    signal s_axi_awready : std_logic_vector(0 to 0);
    signal s_axi_awsize : std_logic_vector(2 downto 0);
    signal s_axi_awvalid : std_logic_vector(0 to 0);
    signal s_axi_bid : std_logic_vector(0 to 0);
    signal s_axi_bready : std_logic_vector(0 to 0);
    signal s_axi_bresp : std_logic_vector(1 downto 0);
    signal s_axi_bvalid : std_logic_vector(0 to 0);
    signal s_axi_rdata : std_logic_vector(511 downto 0);
    signal s_axi_rid : std_logic_vector(0 to 0);
    signal s_axi_rlast : std_logic_vector(0 to 0);
    signal s_axi_rready : std_logic_vector(0 to 0);
    signal s_axi_rresp : std_logic_vector(1 downto 0);
    signal s_axi_rvalid : std_logic_vector(0 to 0);
    signal s_axi_wdata : std_logic_vector(511 downto 0);
    signal s_axi_wlast : std_logic_vector(0 to 0);
    signal s_axi_wready : std_logic_vector(0 to 0);
    signal s_axi_wstrb : std_logic_vector(63 downto 0);
    signal s_axi_wvalid : std_logic_vector(0 to 0);

    -- -------------------------------------------------------------------------
    -- Register interface

    -- Internal register path from AXI conversion
    signal write_strobe : std_ulogic;
    signal write_address : unsigned(13 downto 0);
    signal write_data : std_ulogic_vector(31 downto 0);
    signal write_ack : std_ulogic;
    signal read_strobe : std_ulogic;
    signal read_address : unsigned(13 downto 0);
    signal read_data : std_ulogic_vector(31 downto 0);
    signal read_ack : std_ulogic;

    signal capture_trigger : std_ulogic;
    signal axi_request : axi_request_t;
    signal axi_response : axi_response_t;
    signal axi_stats : std_ulogic_vector(0 to 10);

begin
    -- Clocks and resets
    clocking : entity work.system_clocking port map (
        sysclk100MHz_p => pad_SYSCLK100_P,
        sysclk100MHz_n => pad_SYSCLK100_N,
        clk_o => clk,
        reset_n_o => reset_n,
        pci_reset_n_o => pci_reset_n
    );


    -- -------------------------------------------------------------------------
    -- Interconnect
    interconnect : entity work.interconnect_wrapper port map (
        -- Clocking and reset
        nCOLDRST_i => pci_reset_n,

        -- PCIe MGT interface
        FCLKA_clk_p(0) => pad_MGT224_REFCLK_P,
        FCLKA_clk_n(0) => pad_MGT224_REFCLK_N,
        pcie_7x_mgt_0_rxn => pad_AMC_PCI_RX_N,
        pcie_7x_mgt_0_rxp => pad_AMC_PCI_RX_P,
        pcie_7x_mgt_0_txn => pad_AMC_PCI_TX_N,
        pcie_7x_mgt_0_txp => pad_AMC_PCI_TX_P,

        -- Register clock and AXI reset
        DSP_CLK_i => clk,
        DSP_RESETN_i => reset_n,

        -- AXI-Lite register master to REGS slave interface
        M_DSP_REGS_araddr => M_DSP_REGS_araddr,
        M_DSP_REGS_arprot => M_DSP_REGS_arprot,
        M_DSP_REGS_arready => M_DSP_REGS_arready,
        M_DSP_REGS_arvalid => M_DSP_REGS_arvalid,
        M_DSP_REGS_rdata => M_DSP_REGS_rdata,
        M_DSP_REGS_rresp => M_DSP_REGS_rresp,
        M_DSP_REGS_rready => M_DSP_REGS_rready,
        M_DSP_REGS_rvalid => M_DSP_REGS_rvalid,
        M_DSP_REGS_awaddr => M_DSP_REGS_awaddr,
        M_DSP_REGS_awprot => M_DSP_REGS_awprot,
        M_DSP_REGS_awready => M_DSP_REGS_awready,
        M_DSP_REGS_awvalid => M_DSP_REGS_awvalid,
        M_DSP_REGS_wdata => M_DSP_REGS_wdata,
        M_DSP_REGS_wstrb => M_DSP_REGS_wstrb,
        M_DSP_REGS_wready => M_DSP_REGS_wready,
        M_DSP_REGS_wvalid => M_DSP_REGS_wvalid,
        M_DSP_REGS_bresp => M_DSP_REGS_bresp,
        M_DSP_REGS_bready => M_DSP_REGS_bready,
        M_DSP_REGS_bvalid => M_DSP_REGS_bvalid,

        axi_stats_o => axi_stats,
        setup_trigger_i => capture_trigger,

        s_axi_ACLK_i => clk,
        s_axi_RESETN_i => reset_n,

        s_axi_araddr => s_axi_araddr,
        s_axi_arburst => s_axi_arburst,
        s_axi_arcache => s_axi_arcache,
        s_axi_arid => s_axi_arid,
        s_axi_arlen => s_axi_arlen,
        s_axi_arlock => s_axi_arlock,
        s_axi_arprot => s_axi_arprot,
        s_axi_arqos => s_axi_arqos,
        s_axi_arready => s_axi_arready,
        s_axi_arsize => s_axi_arsize,
        s_axi_arvalid => s_axi_arvalid,
        s_axi_awaddr => s_axi_awaddr,
        s_axi_awburst => s_axi_awburst,
        s_axi_awcache => s_axi_awcache,
        s_axi_awid => s_axi_awid,
        s_axi_awlen => s_axi_awlen,
        s_axi_awlock => s_axi_awlock,
        s_axi_awprot => s_axi_awprot,
        s_axi_awqos => s_axi_awqos,
        s_axi_awready => s_axi_awready,
        s_axi_awsize => s_axi_awsize,
        s_axi_awvalid => s_axi_awvalid,
        s_axi_bid => s_axi_bid,
        s_axi_bready => s_axi_bready,
        s_axi_bresp => s_axi_bresp,
        s_axi_bvalid => s_axi_bvalid,
        s_axi_rdata => s_axi_rdata,
        s_axi_rid => s_axi_rid,
        s_axi_rlast => s_axi_rlast,
        s_axi_rready => s_axi_rready,
        s_axi_rresp => s_axi_rresp,
        s_axi_rvalid => s_axi_rvalid,
        s_axi_wdata => s_axi_wdata,
        s_axi_wlast => s_axi_wlast,
        s_axi_wready => s_axi_wready,
        s_axi_wstrb => s_axi_wstrb,
        s_axi_wvalid => s_axi_wvalid,

        phy_SG12_CK_P => pad_SG12_CK_P,
        phy_SG12_CK_N => pad_SG12_CK_N,
        phy_SG1_WCK_P => pad_SG1_WCK_P,
        phy_SG1_WCK_N => pad_SG1_WCK_N,
        phy_SG2_WCK_P => pad_SG2_WCK_P,
        phy_SG2_WCK_N => pad_SG2_WCK_N,
        phy_SG1_RESET_N => pad_SG1_RESET_N,
        phy_SG2_RESET_N => pad_SG2_RESET_N,
        phy_SG12_CKE_N => pad_SG12_CKE_N,
        phy_SG12_CAL => pad_SG12_CAL,
        phy_SG1_CA3_A => pad_SG1_CA3_A,
        phy_SG1_CA3_B => pad_SG1_CA3_B,
        phy_SG2_CA3_A => pad_SG2_CA3_A,
        phy_SG2_CA3_B => pad_SG2_CA3_B,
        phy_SG12_CAU => pad_SG12_CAU,
        phy_SG12_CABI_N => pad_SG12_CABI_N,
        phy_SG1_DQ_A => pad_SG1_DQ_A,
        phy_SG1_DQ_B => pad_SG1_DQ_B,
        phy_SG2_DQ_A => pad_SG2_DQ_A,
        phy_SG2_DQ_B => pad_SG2_DQ_B,
        phy_SG1_DBI_N_A => pad_SG1_DBI_N_A,
        phy_SG1_DBI_N_B => pad_SG1_DBI_N_B,
        phy_SG2_DBI_N_A => pad_SG2_DBI_N_A,
        phy_SG2_DBI_N_B => pad_SG2_DBI_N_B,
        phy_SG1_EDC_A => pad_SG1_EDC_A,
        phy_SG1_EDC_B => pad_SG1_EDC_B,
        phy_SG2_EDC_A => pad_SG2_EDC_A,
        phy_SG2_EDC_B => pad_SG2_EDC_B
    );


    -- Condense the slave interface
    axi_wrapper : entity work.axi_master_wrapper port map (
        s_axi_araddr_o => s_axi_araddr(31 downto 0),
        s_axi_arburst_o => s_axi_arburst,
        s_axi_arcache_o => s_axi_arcache,
        s_axi_arid_o(0 downto 0) => s_axi_arid,
        s_axi_arid_o(3 downto 1) => "000",
        s_axi_arlen_o => s_axi_arlen,
        s_axi_arlock_o => s_axi_arlock(0),
        s_axi_arprot_o => s_axi_arprot,
        s_axi_arqos_o => s_axi_arqos,
        s_axi_arready_i => s_axi_arready(0),
        s_axi_arsize_o => s_axi_arsize,
        s_axi_arvalid_o => s_axi_arvalid(0),
        s_axi_rdata_i => s_axi_rdata,
        s_axi_rid_i => (0 to 0 => s_axi_rid, others => '0'),
        s_axi_rlast_i => s_axi_rlast(0),
        s_axi_rready_o => s_axi_rready(0),
        s_axi_rresp_i => s_axi_rresp,
        s_axi_rvalid_i => s_axi_rvalid(0),
        s_axi_awaddr_o => s_axi_awaddr(31 downto 0),
        s_axi_awburst_o => s_axi_awburst,
        s_axi_awcache_o => s_axi_awcache,
        s_axi_awid_o(0 downto 0) => s_axi_awid,
        s_axi_awid_o(3 downto 1) => "000",
        s_axi_awlen_o => s_axi_awlen,
        s_axi_awlock_o => s_axi_awlock(0),
        s_axi_awprot_o => s_axi_awprot,
        s_axi_awqos_o => s_axi_awqos,
        s_axi_awready_i => s_axi_awready(0),
        s_axi_awsize_o => s_axi_awsize,
        s_axi_awvalid_o => s_axi_awvalid(0),
        s_axi_wdata_o => s_axi_wdata,
        s_axi_wlast_o => s_axi_wlast(0),
        s_axi_wready_i => s_axi_wready(0),
        s_axi_wstrb_o => s_axi_wstrb,
        s_axi_wvalid_o => s_axi_wvalid(0),
        s_axi_bid_i => (0 to 0 => s_axi_bid, others => '0'),
        s_axi_bready_o => s_axi_bready(0),
        s_axi_bresp_i => s_axi_bresp,
        s_axi_bvalid_i => s_axi_bvalid(0),

        axi_request_i => axi_request,
        axi_response_o => axi_response
    );
    s_axi_araddr(48 downto 32) <= 17X"1_0000";
    s_axi_awaddr(48 downto 32) <= 17X"1_0000";


    -- -------------------------------------------------------------------------
    -- Register control

    -- AXI-lite slave to register interface
    axi_lite_slave : entity work.axi_lite_slave port map (
        clk_i => clk,
        rstn_i => reset_n,

        -- AXI-Lite read interface
        araddr_i => M_DSP_REGS_araddr(15 downto 0),
        arprot_i => M_DSP_REGS_arprot,
        arvalid_i => M_DSP_REGS_arvalid,
        arready_o => M_DSP_REGS_arready,
        rdata_o => M_DSP_REGS_rdata,
        rresp_o => M_DSP_REGS_rresp,
        rvalid_o => M_DSP_REGS_rvalid,
        rready_i => M_DSP_REGS_rready,

        -- AXI-Lite write interface
        awaddr_i => M_DSP_REGS_awaddr(15 downto 0),
        awprot_i => M_DSP_REGS_awprot,
        awvalid_i => M_DSP_REGS_awvalid,
        awready_o => M_DSP_REGS_awready,
        wdata_i => M_DSP_REGS_wdata,
        wstrb_i => M_DSP_REGS_wstrb,
        wvalid_i => M_DSP_REGS_wvalid,
        wready_o => M_DSP_REGS_wready,
        bresp_o => M_DSP_REGS_bresp,
        bvalid_o => M_DSP_REGS_bvalid,
        bready_i => M_DSP_REGS_bready,

        -- Internal register interface
        read_strobe_o => read_strobe,
        read_address_o => read_address,
        read_data_i => read_data,
        read_ack_i => read_ack,
        write_strobe_o => write_strobe,
        write_address_o => write_address,
        write_data_o => write_data,
        write_ack_i => write_ack
    );


    test_gddr6_phy : entity work.test_gddr6_phy generic map (
        CK_FREQUENCY => CK_FREQUENCY
    ) port map (
        clk_i => clk,

        write_strobe_i => write_strobe,
        write_address_i => write_address,
        write_data_i => write_data,
        write_ack_o => write_ack,
        read_strobe_i => read_strobe,
        read_address_i => read_address,
        read_data_o => read_data,
        read_ack_o => read_ack,

        capture_trigger_o => capture_trigger,
        axi_request_o => axi_request,
        axi_response_i => axi_response,
        axi_stats_i => axi_stats,

        pad_LMK_CTL_SEL_o => pad_LMK_CTL_SEL,
        pad_LMK_SCL_o => pad_LMK_SCL,
        pad_LMK_SCS_L_o => pad_LMK_SCS_L,
        pad_LMK_SDIO_io => pad_LMK_SDIO,
        pad_LMK_RESET_L_o => pad_LMK_RESET_L,
        pad_LMK_SYNC_io => pad_LMK_SYNC,
        pad_LMK_STATUS_io => pad_LMK_STATUS
    );


    -- Unconnected LEDs for the moment
    pad_FP_LED2A_K <= '0';
    pad_FP_LED2B_K <= '0';
    pad_FMC1_LED <= (others => '0');
    pad_FMC2_LED <= (others => '0');
end;
