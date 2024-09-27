-- Top level interface to GDDR6 memory controller
--
-- The interface has three components:
--  1. AXI slave interface for memory access
--  2. Simple strobe/ack register interface for configuration
--  3. SG PHY interface for connection to SG memory pins

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_register_defines.all;
use work.register_defs.all;

entity gddr6 is
    generic (
        -- Default SG interface to run at CK=250 MHz, WCK = 1GHz, but support
        -- option to run at 300 MHz/1.2 GHz on speed-grade -2 FPGA
        CK_FREQUENCY : real := 250.0;
        -- In the unlikely case that setup_clk_i is running faster than ck_clk_o
        -- this should be configured so that the correct clock domain crossing
        -- delays are set.  Otherwise leave at the default value.
        REG_FREQUENCY : real := 250.0;
        -- Similarly, if the AXI clock is running fast this should be set
        AXI_FREQUENCY : real := 250.0
    );
    port  (
        -- ---------------------------------------------------------------------
        -- Register Setup Interface
        --
        setup_clk_i : in std_ulogic;
        write_strobe_i : in std_ulogic;
        write_address_i : in unsigned(9 downto 0);
        write_data_i : in std_ulogic_vector(31 downto 0);
        write_ack_o : out std_ulogic;
        read_strobe_i : in std_ulogic;
        read_address_i : in unsigned(9 downto 0);
        read_data_o : out std_ulogic_vector(31 downto 0);
        read_ack_o : out std_ulogic;

        -- ---------------------------------------------------------------------
        -- AXI slave interface to 4GB GDDR6 SGRAM
        --
        -- Clock and reset
        s_axi_ACLK : in std_logic;      -- See note below on naming
        s_axi_RESET_i : in std_logic;
        -- AW
        s_axi_AWID_i : in std_logic_vector(3 downto 0);
        s_axi_AWADDR_i : in std_logic_vector(31 downto 0);
        s_axi_AWLEN_i : in std_logic_vector(7 downto 0);
        s_axi_AWSIZE_i : in std_logic_vector(2 downto 0);
        s_axi_AWBURST_i : in std_logic_vector(1 downto 0);
        s_axi_AWLOCK_i : in std_logic;
        s_axi_AWCACHE_i : in std_logic_vector(3 downto 0);
        s_axi_AWPROT_i : in std_logic_vector(2 downto 0);
        s_axi_AWQOS_i : in std_logic_vector(3 downto 0);
        s_axi_AWUSER_i : in std_logic_vector(3 downto 0);
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
        s_axi_ARLOCK_i : in std_logic;
        s_axi_ARCACHE_i : in std_logic_vector(3 downto 0);
        s_axi_ARPROT_i : in std_logic_vector(2 downto 0);
        s_axi_ARQOS_i : in std_logic_vector(3 downto 0);
        s_axi_ARUSER_i : in std_logic_vector(3 downto 0);
        s_axi_ARVALID_i : in std_logic;
        s_axi_ARREADY_o : out std_logic;
        -- R
        s_axi_RREADY_i : in std_logic;
        s_axi_RLAST_o : out std_logic;
        s_axi_RVALID_o : out std_logic;
        s_axi_RRESP_o : out std_logic_vector(1 downto 0);
        s_axi_RID_o : out std_logic_vector(3 downto 0);
        s_axi_RDATA_o : out std_logic_vector(511 downto 0);

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

architecture arch of gddr6 is
    attribute X_INTERFACE_INFO : string;
    attribute X_INTERFACE_PARAMETER : string;
    attribute X_INTERFACE_IGNORE : string;

    -- Register setup interface
    attribute X_INTERFACE_INFO of setup_clk_i : signal
        is "xilinx.com:signal:clock:1.0 setup_clk clk";
    attribute X_INTERFACE_PARAMETER of setup_clk_i : signal
        is "ASSOCIATED_BUSIF setup";
    attribute X_INTERFACE_INFO of write_strobe_i : signal
        is "dls:user:strobe_ack:1.0 setup write_strobe";
    attribute X_INTERFACE_INFO of write_address_i : signal
        is "dls:user:address_ack:1.0 setup write_address";
    attribute X_INTERFACE_INFO of write_data_i : signal
        is "dls:user:strobe_ack:1.0 setup write_data";
    attribute X_INTERFACE_INFO of write_ack_o : signal
        is "dls:user:strobe_ack:1.0 setup write_ack";
    attribute X_INTERFACE_INFO of read_strobe_i : signal
        is "dls:user:strobe_ack:1.0 setup read_strobe";
    attribute X_INTERFACE_INFO of read_address_i : signal
        is "dls:user:address_ack:1.0 setup read_address";
    attribute X_INTERFACE_INFO of read_data_o : signal
        is "dls:user:strobe_ack:1.0 setup read_data";
    attribute X_INTERFACE_INFO of read_ack_o : signal
        is "dls:user:strobe_ack:1.0 setup read_ack";

    -- AXI slave interface to memory
    --
    -- Clock and reset
    -- Alas, this signal cannot use the _i suffix as the Xilinx IP packager
    -- relies on its inferencing by port name to assign function.  This _IGNORE
    -- attribute has no effect, but is left here in case one day it works...
    attribute X_INTERFACE_IGNORE of s_axi_ACLK : signal is "TRUE";
    attribute X_INTERFACE_INFO of s_axi_ACLK : signal
        is "xilinx.com:signal:clock:1.0 axi_clock clk";
    attribute X_INTERFACE_INFO of s_axi_RESET_i : signal
        is "xilinx.com:signal:reset:1.0 axi_reset rst";
    attribute X_INTERFACE_PARAMETER of s_axi_ACLK : signal
        is "ASSOCIATED_RESET s_axi_RESET_i, " &
           "ASSOCIATED_BUSIF s_axi";
    -- AW
    attribute X_INTERFACE_INFO of s_axi_AWID_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi AWID";
    attribute X_INTERFACE_INFO of s_axi_AWADDR_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi AWADDR";
    attribute X_INTERFACE_INFO of s_axi_AWLEN_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi AWLEN";
    attribute X_INTERFACE_INFO of s_axi_AWSIZE_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi AWSIZE";
    attribute X_INTERFACE_INFO of s_axi_AWBURST_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi AWBURST";
    attribute X_INTERFACE_INFO of s_axi_AWLOCK_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi AWLOCK";
    attribute X_INTERFACE_INFO of s_axi_AWCACHE_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi AWCACHE";
    attribute X_INTERFACE_INFO of s_axi_AWPROT_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi AWPROT";
    attribute X_INTERFACE_INFO of s_axi_AWQOS_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi AWQOS";
    attribute X_INTERFACE_INFO of s_axi_AWUSER_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi AWUSER";
    attribute X_INTERFACE_INFO of s_axi_AWVALID_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi AWVALID";
    attribute X_INTERFACE_INFO of s_axi_AWREADY_o : signal
        is "xilinx.com:interface:aximm:1.0 s_axi AWREADY";
    -- W
    attribute X_INTERFACE_INFO of s_axi_WDATA_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi WDATA";
    attribute X_INTERFACE_INFO of s_axi_WSTRB_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi WSTRB";
    attribute X_INTERFACE_INFO of s_axi_WLAST_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi WLAST";
    attribute X_INTERFACE_INFO of s_axi_WVALID_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi WVALID";
    attribute X_INTERFACE_INFO of s_axi_WREADY_o : signal
        is "xilinx.com:interface:aximm:1.0 s_axi WREADY";
    -- B
    attribute X_INTERFACE_INFO of s_axi_BREADY_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi BREADY";
    attribute X_INTERFACE_INFO of s_axi_BID_o : signal
        is "xilinx.com:interface:aximm:1.0 s_axi BID";
    attribute X_INTERFACE_INFO of s_axi_BRESP_o : signal
        is "xilinx.com:interface:aximm:1.0 s_axi BRESP";
    attribute X_INTERFACE_INFO of s_axi_BVALID_o : signal
        is "xilinx.com:interface:aximm:1.0 s_axi BVALID";
    -- AR
    attribute X_INTERFACE_INFO of s_axi_ARID_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi ARID";
    attribute X_INTERFACE_INFO of s_axi_ARADDR_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi ARADDR";
    attribute X_INTERFACE_INFO of s_axi_ARLEN_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi ARLEN";
    attribute X_INTERFACE_INFO of s_axi_ARSIZE_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi ARSIZE";
    attribute X_INTERFACE_INFO of s_axi_ARBURST_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi ARBURST";
    attribute X_INTERFACE_INFO of s_axi_ARLOCK_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi ARLOCK";
    attribute X_INTERFACE_INFO of s_axi_ARCACHE_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi ARCACHE";
    attribute X_INTERFACE_INFO of s_axi_ARPROT_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi ARPROT";
    attribute X_INTERFACE_INFO of s_axi_ARQOS_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi ARQOS";
    attribute X_INTERFACE_INFO of s_axi_ARUSER_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi ARUSER";
    attribute X_INTERFACE_INFO of s_axi_ARVALID_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi ARVALID";
    attribute X_INTERFACE_INFO of s_axi_ARREADY_o : signal
        is "xilinx.com:interface:aximm:1.0 s_axi ARREADY";
    -- R
    attribute X_INTERFACE_INFO of s_axi_RREADY_i : signal
        is "xilinx.com:interface:aximm:1.0 s_axi RREADY";
    attribute X_INTERFACE_INFO of s_axi_RLAST_o : signal
        is "xilinx.com:interface:aximm:1.0 s_axi RLAST";
    attribute X_INTERFACE_INFO of s_axi_RVALID_o : signal
        is "xilinx.com:interface:aximm:1.0 s_axi RVALID";
    attribute X_INTERFACE_INFO of s_axi_RRESP_o : signal
        is "xilinx.com:interface:aximm:1.0 s_axi RRESP";
    attribute X_INTERFACE_INFO of s_axi_RID_o : signal
        is "xilinx.com:interface:aximm:1.0 s_axi RID";
    attribute X_INTERFACE_INFO of s_axi_RDATA_o : signal
        is "xilinx.com:interface:aximm:1.0 s_axi RDATA";

    -- SG Memory Interface
    attribute X_INTERFACE_INFO of pad_SG1_RESET_N_o : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG1_RESET_N";
    attribute X_INTERFACE_INFO of pad_SG2_RESET_N_o : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG2_RESET_N";
    attribute X_INTERFACE_INFO of pad_SG12_CKE_N_o : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG12_CKE_N";
    attribute X_INTERFACE_INFO of pad_SG12_CK_P_i : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG12_CK_P";
    attribute X_INTERFACE_INFO of pad_SG12_CK_N_i : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG12_CK_N";
    attribute X_INTERFACE_INFO of pad_SG12_CABI_N_o : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG12_CABI_N";
    attribute X_INTERFACE_INFO of pad_SG12_CAL_o : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG12_CAL";
    attribute X_INTERFACE_INFO of pad_SG1_CA3_A_o : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG1_CA3_A";
    attribute X_INTERFACE_INFO of pad_SG1_CA3_B_o : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG1_CA3_B";
    attribute X_INTERFACE_INFO of pad_SG2_CA3_A_o : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG2_CA3_A";
    attribute X_INTERFACE_INFO of pad_SG2_CA3_B_o : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG2_CA3_B";
    attribute X_INTERFACE_INFO of pad_SG12_CAU_o : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG12_CAU";
    attribute X_INTERFACE_INFO of pad_SG1_WCK_P_i : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG1_WCK_P";
    attribute X_INTERFACE_INFO of pad_SG1_WCK_N_i : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG1_WCK_N";
    attribute X_INTERFACE_INFO of pad_SG1_DQ_A_io : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG1_DQ_A";
    attribute X_INTERFACE_INFO of pad_SG1_DBI_N_A_io : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG1_DBI_N_A";
    attribute X_INTERFACE_INFO of pad_SG1_EDC_A_io : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG1_EDC_A";
    attribute X_INTERFACE_INFO of pad_SG1_DQ_B_io : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG1_DQ_B";
    attribute X_INTERFACE_INFO of pad_SG1_DBI_N_B_io : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG1_DBI_N_B";
    attribute X_INTERFACE_INFO of pad_SG1_EDC_B_io : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG1_EDC_B";
    attribute X_INTERFACE_INFO of pad_SG2_WCK_P_i : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG2_WCK_P";
    attribute X_INTERFACE_INFO of pad_SG2_WCK_N_i : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG2_WCK_N";
    attribute X_INTERFACE_INFO of pad_SG2_DQ_A_io : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG2_DQ_A";
    attribute X_INTERFACE_INFO of pad_SG2_DBI_N_A_io : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG2_DBI_N_A";
    attribute X_INTERFACE_INFO of pad_SG2_EDC_A_io : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG2_EDC_A";
    attribute X_INTERFACE_INFO of pad_SG2_DQ_B_io : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG2_DQ_B";
    attribute X_INTERFACE_INFO of pad_SG2_DBI_N_B_io : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG2_DBI_N_B";
    attribute X_INTERFACE_INFO of pad_SG2_EDC_B_io : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 phy SG2_EDC_B";

    signal ck_clk : std_ulogic;

    signal read_request : axi_ctrl_read_request_t;
    signal read_response : axi_ctrl_read_response_t;
    signal write_request : axi_ctrl_write_request_t;
    signal write_response : axi_ctrl_write_response_t;

    signal ctrl_setup : ctrl_setup_t;
    signal ctrl_status : ctrl_status_t;

    signal ca : phy_ca_t;
    signal dq_out : phy_dq_out_t;
    signal dq_in : phy_dq_in_t;

    signal write_strobe : std_ulogic_vector(GDDR6_REGS_RANGE);
    signal write_data : reg_data_array_t(GDDR6_REGS_RANGE);
    signal write_ack : std_ulogic_vector(GDDR6_REGS_RANGE);
    signal read_data : reg_data_array_t(GDDR6_REGS_RANGE);
    signal read_strobe : std_ulogic_vector(GDDR6_REGS_RANGE);
    signal read_ack : std_ulogic_vector(GDDR6_REGS_RANGE);

begin
    axi : entity work.gddr6_axi generic map (
        AXI_FREQUENCY => AXI_FREQUENCY,
        CK_FREQUENCY => CK_FREQUENCY
    ) port map (
        axi_clk_i => s_axi_ACLK,

        axi_wa_i => (
            id => s_axi_AWID_i,
            addr => unsigned(s_axi_AWADDR_i),
            len => unsigned(s_axi_AWLEN_i),
            size => unsigned(s_axi_AWSIZE_i),
            burst => s_axi_AWBURST_i,
            valid => s_axi_AWVALID_i
        ),
        axi_wa_ready_o => s_axi_AWREADY_o,

        axi_w_i => (
            data => s_axi_WDATA_i,
            strb => s_axi_WSTRB_i,
            last => s_axi_WLAST_i,
            valid => s_axi_WVALID_i
        ),
        axi_w_ready_o => s_axi_WREADY_o,

        axi_b_o.id => s_axi_BID_o,
        axi_b_o.resp => s_axi_BRESP_o,
        axi_b_o.valid => s_axi_BVALID_o,
        axi_b_ready_i => s_axi_BREADY_i,

        axi_ra_i => (
            id => s_axi_ARID_i,
            addr => unsigned(s_axi_ARADDR_i),
            len => unsigned(s_axi_ARLEN_i),
            size => unsigned(s_axi_ARSIZE_i),
            burst => s_axi_ARBURST_i,
            valid => s_axi_ARVALID_i
        ),
        axi_ra_ready_o => s_axi_ARREADY_o,

        axi_r_o.id => s_axi_RID_o,
        axi_r_o.data => s_axi_RDATA_o,
        axi_r_o.resp => s_axi_RRESP_o,
        axi_r_o.last => s_axi_RLAST_o,
        axi_r_o.valid => s_axi_RVALID_o,
        axi_r_ready_i => s_axi_RREADY_i,

        ck_clk_i => ck_clk,
        ctrl_read_request_o => read_request,
        ctrl_read_response_i => read_response,
        ctrl_write_request_o => write_request,
        ctrl_write_response_i => write_response
    );

    ctrl : entity work.gddr6_ctrl port map (
        clk_i => ck_clk,

        ctrl_setup_i => ctrl_setup,
        ctrl_status_o => ctrl_status,

        axi_read_request_i => read_request,
        axi_read_response_o => read_response,
        axi_write_request_i => write_request,
        axi_write_response_o => write_response,

        phy_ca_o => ca,
        phy_dq_o => dq_out,
        phy_dq_i => dq_in
    );

    register_mux : entity work.register_mux port map (
        clk_i => setup_clk_i,

        write_strobe_i => write_strobe_i,
        write_address_i => write_address_i,
        write_data_i => write_data_i,
        write_ack_o => write_ack_o,
        read_strobe_i => read_strobe_i,
        read_address_i => read_address_i,
        read_data_o => read_data_o,
        read_ack_o => read_ack_o,

        write_strobe_o => write_strobe,
        write_data_o => write_data,
        write_ack_i => write_ack,
        read_data_i => read_data,
        read_strobe_o => read_strobe,
        read_ack_i => read_ack
    );

    setup_phy : entity work.gddr6_setup_phy generic map (
        CK_FREQUENCY => CK_FREQUENCY,
        REG_FREQUENCY => REG_FREQUENCY
    ) port map (
        reg_clk_i => setup_clk_i,
        ck_clk_o => ck_clk,

        write_strobe_i => write_strobe,
        write_data_i => write_data,
        write_ack_o => write_ack,
        read_strobe_i => read_strobe,
        read_data_o => read_data,
        read_ack_o => read_ack,

        ctrl_ca_i => ca,
        ctrl_dq_i => dq_out,
        ctrl_dq_o => dq_in,

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
end;
