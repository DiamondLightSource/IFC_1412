library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.register_defines.all;

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

    -- System register wiring
    signal sys_write_strobe : std_ulogic_vector(SYS_REGS_RANGE);
    signal sys_write_data : reg_data_array_t(SYS_REGS_RANGE);
    signal sys_write_ack : std_ulogic_vector(SYS_REGS_RANGE);
    signal sys_read_strobe : std_ulogic_vector(SYS_REGS_RANGE);
    signal sys_read_data : reg_data_array_t(SYS_REGS_RANGE);
    signal sys_read_ack : std_ulogic_vector(SYS_REGS_RANGE);

    -- GDDR6 register wiring
    signal phy_write_strobe : std_ulogic_vector(PHY_REGS_RANGE);
    signal phy_write_data : reg_data_array_t(PHY_REGS_RANGE);
    signal phy_write_ack : std_ulogic_vector(PHY_REGS_RANGE);
    signal phy_read_strobe : std_ulogic_vector(PHY_REGS_RANGE);
    signal phy_read_data : reg_data_array_t(PHY_REGS_RANGE);
    signal phy_read_ack : std_ulogic_vector(PHY_REGS_RANGE);


    -- -------------------------------------------------------------------------

    -- LMK config and status
    signal lmk_command_select : std_ulogic;
    signal lmk_status : std_ulogic_vector(1 downto 0);
    signal lmk_reset : std_ulogic;
    signal lmk_sync : std_ulogic;

    -- SPI interface to LMK
    signal lmk_write_strobe : std_ulogic;
    signal lmk_write_ack : std_ulogic;
    signal lmk_read_write_n : std_ulogic;
    signal lmk_address : std_ulogic_vector(14 downto 0);
    signal lmk_data_in : std_ulogic_vector(7 downto 0);
    signal lmk_write_select : std_ulogic;
    signal lmk_read_strobe : std_ulogic;
    signal lmk_read_ack : std_ulogic;
    signal lmk_data_out : std_ulogic_vector(7 downto 0);

    -- SG clocking and reset control
    signal ck_clk : std_ulogic;
    signal riu_clk : std_ulogic;
    signal ck_reset : std_ulogic;
    signal raw_ck_clk_ok : std_ulogic;      -- Unsynchronised
    signal ck_clk_ok : std_ulogic;
    signal ck_unlock : std_ulogic;
    signal fifo_ok : std_ulogic;
    signal sg_resets : std_ulogic_vector(0 to 1);

    -- SG CA and initial EDC
    signal ca : vector_array(0 to 1)(9 downto 0);
    signal ca3 : std_ulogic_vector(0 to 3);
    signal cke_n : std_ulogic;
    signal enable_cabi : std_ulogic;
    signal edc_cfg : std_ulogic_vector(7 downto 0);
    signal edc_t : std_ulogic;

    -- SG DQ signals
    signal dq_data_in : std_ulogic_vector(511 downto 0);
    signal dq_data_out : std_ulogic_vector(511 downto 0);
    signal dq_t : std_ulogic;
    signal enable_dbi : std_ulogic;
    signal edc_in : vector_array(7 downto 0)(7 downto 0);
    signal edc_out : vector_array(7 downto 0)(7 downto 0);

    -- SG RIU control
    signal riu_addr : unsigned(9 downto 0);
    signal riu_wr_data : std_ulogic_vector(15 downto 0);
    signal riu_rd_data : std_ulogic_vector(15 downto 0);
    signal riu_wr_en : std_ulogic;
    signal riu_strobe : std_ulogic;
    signal riu_ack : std_ulogic;

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


    -- Decode registers into system and GDDR6 registers
    decode_registers : entity work.decode_registers port map (
        clk_i => clk,
        riu_clk_ok_i => ck_clk_ok,
        riu_clk_i => riu_clk,

        -- Internal registers from AXI-lite
        write_strobe_i => regs_write_strobe,
        write_address_i => regs_write_address,
        write_data_i => regs_write_data,
        write_ack_o => regs_write_ack,
        read_strobe_i => regs_read_strobe,
        read_address_i => regs_read_address,
        read_data_o => regs_read_data,
        read_ack_o => regs_read_ack,

        -- System registers on clk domain
        sys_write_strobe_o => sys_write_strobe,
        sys_write_data_o => sys_write_data,
        sys_write_ack_i => sys_write_ack,
        sys_read_data_i => sys_read_data,
        sys_read_strobe_o => sys_read_strobe,
        sys_read_ack_i => sys_read_ack,

        -- GDDR6 PHY registers on riu_clk domain
        phy_write_strobe_o => phy_write_strobe,
        phy_write_data_o => phy_write_data,
        phy_write_ack_i => phy_write_ack,
        phy_read_data_i => phy_read_data,
        phy_read_strobe_o => phy_read_strobe,
        phy_read_ack_i => phy_read_ack
    );


    -- SYS registers
    system_registers : entity work.system_registers port map (
        clk_i => clk,

        write_strobe_i => sys_write_strobe,
        write_data_i => sys_write_data,
        write_ack_o => sys_write_ack,
        read_strobe_i => sys_read_strobe,
        read_data_o => sys_read_data,
        read_ack_o => sys_read_ack,

        lmk_command_select_o => lmk_command_select,
        lmk_status_i => lmk_status,
        lmk_reset_o => lmk_reset,
        lmk_sync_o => lmk_sync,

        lmk_write_strobe_o => lmk_write_strobe,
        lmk_write_ack_i => lmk_write_ack,
        lmk_read_write_n_o => lmk_read_write_n,
        lmk_address_o => lmk_address,
        lmk_data_o => lmk_data_out,
        lmk_write_select_o => lmk_write_select,
        lmk_read_strobe_o => lmk_read_strobe,
        lmk_read_ack_i => lmk_read_ack,
        lmk_data_i => lmk_data_in,

        ck_reset_o => ck_reset,
        ck_locked_i => ck_clk_ok
    );


    gddr6_registers : entity work.gddr6_registers port map (
        clk_i => riu_clk,

        write_strobe_i => phy_write_strobe,
        write_data_i => phy_write_data,
        write_ack_o => phy_write_ack,
        read_strobe_i => phy_read_strobe,
        read_data_o => phy_read_data,
        read_ack_o => phy_read_ack,

        ck_unlock_i => ck_unlock,
        fifo_ok_i => fifo_ok,

        sg_resets_o => sg_resets,
        enable_cabi_o => enable_cabi,
        enable_dbi_o => enable_dbi,
        edc_t_o => edc_t,
        dq_t_o => dq_t,

        ca_o => ca,
        ca3_o => ca3,
        cke_n_o => cke_n,

        dq_data_i => dq_data_in,
        dq_data_o => dq_data_out,
        edc_in_i => edc_in,
        edc_out_i => edc_out,

        riu_addr_o => riu_addr,
        riu_wr_data_o => riu_wr_data,
        riu_rd_data_i => riu_rd_data,
        riu_wr_en_o => riu_wr_en,
        riu_strobe_o => riu_strobe,
        riu_ack_i => riu_ack
    );


    -- -------------------------------------------------------------------------
    -- Device interfaces


    lmk04616 : entity work.lmk04616 port map (
        clk_i => clk,

        command_select_i => lmk_command_select,
        select_valid_o => open,
        status_o => lmk_status,
        reset_i => lmk_reset,
        sync_i => lmk_sync,

        write_strobe_i => lmk_write_strobe,
        write_ack_o => lmk_write_ack,
        read_write_n_i => lmk_read_write_n,
        address_i => lmk_address,
        data_i => lmk_data_out,
        write_select_i => lmk_write_select,

        read_strobe_i => lmk_read_strobe,
        read_ack_o => lmk_read_ack,
        data_o => lmk_data_in,

        pad_LMK_CTL_SEL_o => pad_LMK_CTL_SEL,
        pad_LMK_SCL_o => pad_LMK_SCL,
        pad_LMK_SCS_L_o => pad_LMK_SCS_L,
        pad_LMK_SDIO_io => pad_LMK_SDIO,
        pad_LMK_RESET_L_o => pad_LMK_RESET_L,
        pad_LMK_SYNC_io => pad_LMK_SYNC,
        pad_LMK_STATUS_io => pad_LMK_STATUS
    );


    phy : entity work.gddr6_phy generic map (
        CK_FREQUENCY => CK_FREQUENCY
    ) port map (
        ck_clk_o => ck_clk,
        riu_clk_o => riu_clk,
        ck_reset_i => ck_reset,
        ck_ok_o => raw_ck_clk_ok,
        ck_unlock_o => ck_unlock,
        fifo_ok_o => fifo_ok,

        sg_resets_i => sg_resets,

        ca_i => ca,
        ca3_i => ca3,
        cke_n_i => cke_n,
        enable_cabi_i => enable_cabi,
        edc_i => edc_cfg,
        edc_t_i => edc_t,

        data_i => dq_data_out,
        data_o => dq_data_in,
        dq_t_i => dq_t,
        enable_dbi_i => enable_dbi,
        edc_in_o => edc_in,
        edc_out_o => edc_out,

        riu_addr_i => riu_addr,
        riu_wr_data_i => riu_wr_data,
        riu_rd_data_o => riu_rd_data,
        riu_wr_en_i => riu_wr_en,
        riu_strobe_i => riu_strobe,
        riu_ack_o => riu_ack,

        pad_SG12_CK_P_i => pad_SG12_CK_P,
        pad_SG12_CK_N_i => pad_SG12_CK_N,
        pad_SG1_WCK_P_i => pad_SG1_WCK_P,
        pad_SG1_WCK_N_i => pad_SG1_WCK_N,
        pad_SG2_WCK_P_i => pad_SG2_WCK_P,
        pad_SG2_WCK_N_i => pad_SG2_WCK_N,
        pad_SG1_RESET_N_o => pad_SG1_RESET_N,
        pad_SG2_RESET_N_o => pad_SG2_RESET_N,
        pad_SG12_CKE_N_o => pad_SG12_CKE_N,
        pad_SG12_CABI_N_o => pad_SG12_CABI_N,
        pad_SG12_CAL_o => pad_SG12_CAL,
        pad_SG1_CA3_A_o => pad_SG1_CA3_A,
        pad_SG1_CA3_B_o => pad_SG1_CA3_B,
        pad_SG2_CA3_A_o => pad_SG2_CA3_A,
        pad_SG2_CA3_B_o => pad_SG2_CA3_B,
        pad_SG12_CAU_o => pad_SG12_CAU,
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
    edc_cfg <= X"FF";

    sync_ck_ok : entity work.sync_bit port map (
        clk_i => clk,
        bit_i => raw_ck_clk_ok,
        bit_o => ck_clk_ok
    );


    -- Unconnected LEDs for the moment
    pad_FP_LED2A_K <= '0';
    pad_FP_LED2B_K <= '0';
    pad_FMC1_LED <= (others => '0');
    pad_FMC2_LED <= (others => '0');
end;
