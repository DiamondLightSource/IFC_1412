library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.support.all;

use work.register_defs.all;
use work.register_defines.all;

architecture arch of top is
    -- Clocks and resets
    signal clk : std_ulogic;
    signal reset_n : std_ulogic;
    -- We need a separate PCIe Reset signal which is marked as asynchronous
    signal perst_n : std_ulogic;

    -- Test clocks
    signal test_clocks : std_ulogic_vector(0 to 3);
    signal test_clock_counts : unsigned_array(0 to 3)(31 downto 0);
    signal test_clock_update : std_ulogic;

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

    -- System register wiring
    signal system_write_strobe : std_ulogic_vector(TOP_REGS_RANGE);
    signal system_write_data : reg_data_array_t(TOP_REGS_RANGE);
    signal system_write_ack : std_ulogic_vector(TOP_REGS_RANGE);
    signal system_read_strobe : std_ulogic_vector(TOP_REGS_RANGE);
    signal system_read_data : reg_data_array_t(TOP_REGS_RANGE);
    signal system_read_ack : std_ulogic_vector(TOP_REGS_RANGE);

    -- Internal register path from AXI conversion
    signal REGS_write_strobe : std_ulogic;
    signal REGS_write_address : unsigned(13 downto 0);
    signal REGS_write_data : std_ulogic_vector(31 downto 0);
    signal REGS_write_ack : std_ulogic;
    signal REGS_read_strobe : std_ulogic;
    signal REGS_read_address : unsigned(13 downto 0);
    signal REGS_read_data : std_ulogic_vector(31 downto 0);
    signal REGS_read_ack : std_ulogic;

    -- Decoded register wiring
    signal top_write_strobe : std_ulogic_vector(TOP_REGS_RANGE);
    signal top_write_data : reg_data_array_t(TOP_REGS_RANGE);
    signal top_write_ack : std_ulogic_vector(TOP_REGS_RANGE);
    signal top_read_strobe : std_ulogic_vector(TOP_REGS_RANGE);
    signal top_read_data : reg_data_array_t(TOP_REGS_RANGE);
    signal top_read_ack : std_ulogic_vector(TOP_REGS_RANGE);

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

begin
    -- Clocks and resets
    clocking : entity work.system_clocking port map (
        sysclk100MHz_p => pad_SYSCLK100_P,
        sysclk100MHz_n => pad_SYSCLK100_N,
        clk_o => clk,
        reset_n_o => reset_n,
        perst_n_o => perst_n
    );

    -- Four clock inputs
    i_sg12_ck : IBUFDS port map (
        I => pad_SG12_CK_P,
        IB => pad_SG12_CK_N,
        O => test_clocks(0)
    );

    i_sg1_wck : IBUFDS port map (
        I => pad_SG1_WCK_P,
        IB => pad_SG1_WCK_N,
        O => test_clocks(1)
    );

    i_sg2_wck : IBUFDS port map (
        I => pad_SG2_WCK_P,
        IB => pad_SG2_WCK_N,
        O => test_clocks(2)
    );

    -- Cannot readily pick up any other clock input.
    test_clocks(3) <= '0';


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
    -- AXI interfacing

    -- Register AXI slave interface
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

        -- Internal read interface
        read_strobe_o => REGS_read_strobe,
        read_address_o => REGS_read_address,
        read_data_i => REGS_read_data,
        read_ack_i => REGS_read_ack,

        -- Internal write interface
        write_strobe_o => REGS_write_strobe,
        write_address_o => REGS_write_address,
        write_data_o => REGS_write_data,
        write_ack_i => REGS_write_ack
    );


    -- Decode register addresses
    register_mux : entity work.register_mux generic map (
        BUFFER_DEPTH => 1
    ) port map (
        clk_i => clk,

        -- From AXI slave
        write_strobe_i => REGS_write_strobe,
        write_address_i => REGS_write_address,
        write_data_i => REGS_write_data,
        write_ack_o => REGS_write_ack,
        read_strobe_i => REGS_read_strobe,
        read_address_i => REGS_read_address,
        read_data_o => REGS_read_data,
        read_ack_o => REGS_read_ack,

        -- Decoded registers
        write_strobe_o => top_write_strobe,
        write_data_o => top_write_data,
        write_ack_i => top_write_ack,
        read_strobe_o => top_read_strobe,
        read_data_i => top_read_data,
        read_ack_i => top_read_ack
    );


    -- -------------------------------------------------------------------------

    -- Top level register support
    top_registers : entity work.top_registers port map (
        clk_i => clk,

        write_strobe_i => top_write_strobe,
        write_data_i => top_write_data,
        write_ack_o => top_write_ack,
        read_strobe_i => top_read_strobe,
        read_data_o => top_read_data,
        read_ack_o => top_read_ack,

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

        clock_counts_i => test_clock_counts,
        clock_update_i => test_clock_update
    );


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


    -- Frequency counters for a handful of clocks
    counters : entity work.frequency_counters generic map (
        COUNT => 4
    ) port map (
        clk_i => clk,
        clk_in_i => test_clocks,
        counts_o => test_clock_counts,
        update_o => test_clock_update
    );


    -- Unconnected LEDs for the moment
    pad_FP_LED2A_K <= '0';
    pad_FP_LED2B_K <= '0';
    pad_FMC1_LED <= (others => '0');
    pad_FMC2_LED <= (others => '0');
end;
