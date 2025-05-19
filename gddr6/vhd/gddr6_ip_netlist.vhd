-- Wrapper interface to gddr6 designed to support Xilinx IP generation
--
-- Generates netlist for inclusion in IP block

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.gddr6_register_defines.all;
use work.gddr6_defs.all;
use work.gddr6_ip_defs.all;

entity gddr6_ip_netlist is
    port (
        -- ---------------------------------------------------------------------
        -- Register Setup Interface
        --
        s_reg_ACLK : in std_ulogic;
        s_reg_RESETN_i : in std_ulogic := '1';
        -- AR
        s_reg_ARADDR_i : in std_ulogic_vector(11 downto 0);
        s_reg_ARVALID_i : in std_ulogic;
        s_reg_ARREADY_o : out std_ulogic;
        -- AW
        s_reg_AWADDR_i : in std_ulogic_vector(11 downto 0);
        s_reg_AWVALID_i : in std_ulogic;
        s_reg_AWREADY_o : out std_ulogic;
        -- B
        s_reg_BRESP_o : out std_ulogic_vector(1 downto 0);
        s_reg_BVALID_o : out std_ulogic;
        s_reg_BREADY_i : in std_ulogic;
        -- R
        s_reg_RDATA_o : out std_ulogic_vector(31 downto 0);
        s_reg_RRESP_o : out std_ulogic_vector(1 downto 0);
        s_reg_RVALID_o : out std_ulogic;
        s_reg_RREADY_i : in std_ulogic;
        -- W
        s_reg_WDATA_i : in std_ulogic_vector(31 downto 0);
        s_reg_WSTRB_i : in std_ulogic_vector(3 downto 0);
        s_reg_WVALID_i : in std_ulogic;
        s_reg_WREADY_o : out std_ulogic;


        -- Optional trigger (on reg clock) to capture SG transactions
        setup_trigger_i : in std_ulogic := '0';


        -- ---------------------------------------------------------------------
        -- AXI slave interface to 4GB GDDR6 SGRAM
        --
        -- Clock and reset
        s_axi_ACLK : in std_logic;      -- See note below on naming
        s_axi_RESETN_i : in std_ulogic := '1';
        -- AW
        s_axi_AWID_i : in std_logic_vector(3 downto 0);
        s_axi_AWADDR_i : in std_logic_vector(31 downto 0);
        s_axi_AWLEN_i : in std_logic_vector(7 downto 0);
        s_axi_AWSIZE_i : in std_logic_vector(2 downto 0);
        s_axi_AWBURST_i : in std_logic_vector(1 downto 0);
        s_axi_AWVALID_i : in std_logic;
        s_axi_AWREADY_o : out std_logic;
        -- W
        s_axi_WDATA_i : in std_logic_vector(511 downto 0);
        s_axi_WSTRB_i : in std_logic_vector(63 downto 0);
        s_axi_WLAST_i : in std_logic;
        s_axi_WVALID_i : in std_logic;
        s_axi_WREADY_o : out std_logic;
        -- B
        s_axi_BREADY_i : in std_logic;
        s_axi_BID_o : out std_logic_vector(3 downto 0);
        s_axi_BRESP_o : out std_logic_vector(1 downto 0);
        s_axi_BVALID_o : out std_logic;
        -- AR
        s_axi_ARID_i : in std_logic_vector(3 downto 0);
        s_axi_ARADDR_i : in std_logic_vector(31 downto 0);
        s_axi_ARLEN_i : in std_logic_vector(7 downto 0);
        s_axi_ARSIZE_i : in std_logic_vector(2 downto 0);
        s_axi_ARBURST_i : in std_logic_vector(1 downto 0);
        s_axi_ARVALID_i : in std_logic;
        s_axi_ARREADY_o : out std_logic;
        -- R
        s_axi_RREADY_i : in std_logic;
        s_axi_RLAST_o : out std_logic;
        s_axi_RVALID_o : out std_logic;
        s_axi_RRESP_o : out std_logic_vector(1 downto 0);
        s_axi_RID_o : out std_logic_vector(3 downto 0);
        s_axi_RDATA_o : out std_logic_vector(511 downto 0);


        -- AXI statistics events generated on AXI memory clock
        axi_stats_o : out std_ulogic_vector(0 to 10);


        -- ---------------------------------------------------------- --
        -- GDDR6 PHY Interface                                        --
        pad_SG1_RESET_N_o : out std_logic;
        pad_SG2_RESET_N_o : out std_logic;
        pad_SG12_CKE_N_o : out std_logic;
        pad_SG12_CK_P_i : in std_logic;
        pad_SG12_CK_N_i : in std_logic;

        pad_SG12_CABI_N_o : out std_logic;
        pad_SG12_CAL_o : out std_logic_vector(2 downto 0);
        pad_SG1_CA3_A_o : out std_logic;
        pad_SG1_CA3_B_o : out std_logic;
        pad_SG2_CA3_A_o : out std_logic;
        pad_SG2_CA3_B_o : out std_logic;
        pad_SG12_CAU_o : out std_logic_vector(9 downto 4);

        pad_SG1_WCK_P_i : in std_logic;
        pad_SG1_WCK_N_i : in std_logic;

        pad_SG1_DQ_A_io : inout std_logic_vector(15 downto 0);
        pad_SG1_DBI_N_A_io : inout std_logic_vector(1 downto 0);
        pad_SG1_EDC_A_io : inout std_logic_vector(1 downto 0);
        pad_SG1_DQ_B_io : inout std_logic_vector(15 downto 0);
        pad_SG1_DBI_N_B_io : inout std_logic_vector(1 downto 0);
        pad_SG1_EDC_B_io : inout std_logic_vector(1 downto 0);

        pad_SG2_WCK_P_i : in std_logic;
        pad_SG2_WCK_N_i : in std_logic;

        pad_SG2_DQ_A_io : inout std_logic_vector(15 downto 0);
        pad_SG2_DBI_N_A_io : inout std_logic_vector(1 downto 0);
        pad_SG2_EDC_A_io : inout std_logic_vector(1 downto 0);
        pad_SG2_DQ_B_io : inout std_logic_vector(15 downto 0);
        pad_SG2_DBI_N_B_io : inout std_logic_vector(1 downto 0);
        pad_SG2_EDC_B_io : inout std_logic_vector(1 downto 0)
    );
end;

architecture arch of gddr6_ip_netlist is
    -- Default SG interface to run at CK=250 MHz, WCK = 1GHz, but support
    -- option to run at 300 MHz/1.2 GHz on speed-grade -2 FPGA
    constant CK_FREQUENCY : real := 250.0;
    -- In the unlikely case that setup_clk_i is running faster than ck_clk_o
    -- this should be configured so that the correct clock domain crossing
    -- delays are set.  Otherwise leave at the default value.
    constant REG_FREQUENCY : real := 250.0;
    -- Similarly, if the AXI clock is running fast this should be set
    constant AXI_FREQUENCY : real := 250.0;


    -- AXI-Lite decoded to strobe/ack + address register interface
    signal raw_read_strobe : std_ulogic;
    signal raw_read_address : unsigned(8 downto 0);
    signal raw_read_data : std_ulogic_vector(31 downto 0);
    signal raw_read_ack : std_ulogic;
    signal raw_write_strobe : std_ulogic;
    signal raw_write_address : unsigned(8 downto 0);
    signal raw_write_data : std_ulogic_vector(31 downto 0);
    signal raw_write_ack : std_ulogic;

    -- Register interface decoded to GDDR6 control registers
    signal write_strobe : std_ulogic_vector(GDDR6_REGS_RANGE);
    signal write_data : reg_data_array_t(GDDR6_REGS_RANGE);
    signal write_ack : std_ulogic_vector(GDDR6_REGS_RANGE);
    signal read_data : reg_data_array_t(GDDR6_REGS_RANGE);
    signal read_strobe : std_ulogic_vector(GDDR6_REGS_RANGE);
    signal read_ack : std_ulogic_vector(GDDR6_REGS_RANGE);

    -- Intermediate signals needed for adaption to IP support
    signal axi_request : axi_request_t;
    signal axi_stats : axi_stats_t;

begin
    -- Decode AXI-Lite as Strobe/Ack
    axi : entity work.axi_lite_slave port map (
        clk_i => s_reg_ACLK,
        rstn_i => s_reg_RESETN_i,

        araddr_i => s_reg_ARADDR_i,
        arprot_i => "000",
        arready_o => s_reg_ARREADY_o,
        arvalid_i => s_reg_ARVALID_i,
        rdata_o => s_reg_RDATA_o,
        rresp_o => s_reg_RRESP_o,
        rready_i => s_reg_RREADY_i,
        rvalid_o => s_reg_RVALID_o,

        awaddr_i => s_reg_AWADDR_i,
        awprot_i => "000",
        awready_o => s_reg_AWREADY_o,
        awvalid_i => s_reg_AWVALID_i,
        wdata_i => s_reg_WDATA_i,
        wstrb_i => s_reg_WSTRB_i,
        wready_o => s_reg_WREADY_o,
        wvalid_i => s_reg_WVALID_i,
        bresp_o => s_reg_BRESP_o,
        bready_i => s_reg_BREADY_i,
        bvalid_o => s_reg_BVALID_o,

        read_strobe_o => raw_read_strobe,
        read_address_o => raw_read_address,
        read_data_i => raw_read_data,
        read_ack_i => raw_read_ack,
        write_strobe_o => raw_write_strobe,
        write_address_o => raw_write_address,
        write_data_o => raw_write_data,
        write_ack_i => raw_write_ack
    );

    -- Decode register address
    mux : entity work.register_mux port map (
        clk_i => s_reg_ACLK,

        write_strobe_i => raw_write_strobe,
        write_address_i => raw_write_address,
        write_data_i => raw_write_data,
        write_ack_o => raw_write_ack,
        read_strobe_i => raw_read_strobe,
        read_address_i => raw_read_address,
        read_data_o => raw_read_data,
        read_ack_o => raw_read_ack,

        write_strobe_o => write_strobe,
        write_data_o => write_data,
        write_ack_i => write_ack,
        read_data_i => read_data,
        read_strobe_o => read_strobe,
        read_ack_i => read_ack
    );


    -- Plumbing of incoming AXI request
    axi_request <= (
        write_address => (
            id => s_axi_AWID_i,
            addr => unsigned(s_axi_AWADDR_i),
            len => unsigned(s_axi_AWLEN_i),
            size => unsigned(s_axi_AWSIZE_i),
            burst => s_axi_AWBURST_i,
            valid => s_axi_AWVALID_i
        ),
        write_data => (
            data => s_axi_WDATA_i,
            strb => s_axi_WSTRB_i,
            last => s_axi_WLAST_i,
            valid => s_axi_WVALID_i
        ),
        write_response_ready => s_axi_BREADY_i,
        read_address => (
            id => s_axi_ARID_i,
            addr => unsigned(s_axi_ARADDR_i),
            len => unsigned(s_axi_ARLEN_i),
            size => unsigned(s_axi_ARSIZE_i),
            burst => s_axi_ARBURST_i,
            valid => s_axi_ARVALID_i
        ),
        read_data_ready => s_axi_RREADY_i
    );


    -- Do we want to support s_axi_RESETN_i?  This is only needed if there is
    -- the possibility of invalid incoming requests during reset.

    -- Core memory controller
    gddr6 : entity work.gddr6 generic map (
        AXI_FREQUENCY => AXI_FREQUENCY,
        REG_FREQUENCY => REG_FREQUENCY,
        CK_FREQUENCY => CK_FREQUENCY
    ) port map (
        setup_clk_i => s_reg_ACLK,

        write_strobe_i => write_strobe,
        write_data_i => write_data,
        write_ack_o => write_ack,
        read_strobe_i => read_strobe,
        read_data_o => read_data,
        read_ack_o => read_ack,

        setup_trigger_i => setup_trigger_i,

        axi_clk_i => s_axi_ACLK,

        axi_request_i => axi_request,

        axi_response_o.write_address_ready => s_axi_AWREADY_o,
        axi_response_o.write_data_ready => s_axi_WREADY_o,
        axi_response_o.write_response.id => s_axi_BID_o,
        axi_response_o.write_response.resp => s_axi_BRESP_o,
        axi_response_o.write_response.valid => s_axi_BVALID_o,
        axi_response_o.read_address_ready => s_axi_ARREADY_o,
        axi_response_o.read_data.id => s_axi_RID_o,
        axi_response_o.read_data.data => s_axi_RDATA_o,
        axi_response_o.read_data.resp => s_axi_RRESP_o,
        axi_response_o.read_data.last => s_axi_RLAST_o,
        axi_response_o.read_data.valid => s_axi_RVALID_o,

        axi_stats_o => axi_stats,

        pad_SG12_CK_P_i => pad_SG12_CK_P_i,
        pad_SG12_CK_N_i => pad_SG12_CK_N_i,
        pad_SG1_WCK_P_i => pad_SG1_WCK_P_i,
        pad_SG1_WCK_N_i => pad_SG1_WCK_N_i,
        pad_SG2_WCK_P_i => pad_SG2_WCK_P_i,
        pad_SG2_WCK_N_i => pad_SG2_WCK_N_i,
        pad_SG1_RESET_N_o => pad_SG1_RESET_N_o,
        pad_SG2_RESET_N_o => pad_SG2_RESET_N_o,
        pad_SG12_CKE_N_o => pad_SG12_CKE_N_o,
        pad_SG12_CABI_N_o => pad_SG12_CABI_N_o,
        pad_SG12_CAL_o => pad_SG12_CAL_o,
        pad_SG1_CA3_A_o => pad_SG1_CA3_A_o,
        pad_SG1_CA3_B_o => pad_SG1_CA3_B_o,
        pad_SG2_CA3_A_o => pad_SG2_CA3_A_o,
        pad_SG2_CA3_B_o => pad_SG2_CA3_B_o,
        pad_SG12_CAU_o => pad_SG12_CAU_o,
        pad_SG1_DQ_A_io => pad_SG1_DQ_A_io,
        pad_SG1_DQ_B_io => pad_SG1_DQ_B_io,
        pad_SG2_DQ_A_io => pad_SG2_DQ_A_io,
        pad_SG2_DQ_B_io => pad_SG2_DQ_B_io,
        pad_SG1_DBI_N_A_io => pad_SG1_DBI_N_A_io,
        pad_SG1_DBI_N_B_io => pad_SG1_DBI_N_B_io,
        pad_SG2_DBI_N_A_io => pad_SG2_DBI_N_A_io,
        pad_SG2_DBI_N_B_io => pad_SG2_DBI_N_B_io,
        pad_SG1_EDC_A_io => pad_SG1_EDC_A_io,
        pad_SG1_EDC_B_io => pad_SG1_EDC_B_io,
        pad_SG2_EDC_A_io => pad_SG2_EDC_A_io,
        pad_SG2_EDC_B_io => pad_SG2_EDC_B_io
    );

    -- Flatten the AXI statistics for IP output
    axi_stats_o <= to_std_ulogic_vector(axi_stats);
end;
