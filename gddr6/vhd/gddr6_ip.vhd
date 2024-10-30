-- Wrapper interface to gddr6 designed to support Xilinx IP generation
--
-- The following requirements ensure that the Viviado IP Packager works:
--  * This file must be VHDL-1993 compatible.
--  * Generics cannot be reals.
--  * The X_INTERFACE_INFO attributes guide the packager, and must be in the
--    architecture part.
--  * Ports can only be std_ulogic or std_ulogic_vector, no structures or higher
--    dimensional arrays.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.gddr6_register_defines.all;
use work.gddr6_defs.all;

entity gddr6_ip is
    -- Note that the parameters below *should* be real values, but as documented
    -- in https://adaptivesupport.amd.com/s/article/58038 this is not supported
    -- by the Vivado IP Packager.
    generic (
        -- Default SG interface to run at CK=250 MHz, WCK = 1GHz, but support
        -- option to run at 300 MHz/1.2 GHz on speed-grade -2 FPGA
        CK_FREQUENCY : natural := 250;
        -- In the unlikely case that setup_clk_i is running faster than ck_clk_o
        -- this should be configured so that the correct clock domain crossing
        -- delays are set.  Otherwise leave at the default value.
        REG_FREQUENCY : natural := 250;
        -- Similarly, if the AXI clock is running fast this should be set
        AXI_FREQUENCY : natural := 250
    );
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

architecture arch of gddr6_ip is
    -- X-Interface attributes for correct IP Integrator inference
    attribute X_INTERFACE_INFO : string;
    attribute X_INTERFACE_PARAMETER : string;

    -- Note that the AXI clock signal cannot use the _i suffix as the Xilinx IP
    -- packager relies on its inferencing by port name to assign function.


    -- AXI-Lite Slave Interface
    --
    attribute X_INTERFACE_INFO of s_reg_ACLK : signal
        is "xilinx.com:signal:clock:1.0 s_reg_ACLK clk";
    attribute X_INTERFACE_INFO of s_reg_RESETN_i : signal
        is "xilinx.com:signal:reset:1.0 s_reg_RESETN_i rst";
    attribute X_INTERFACE_PARAMETER of s_reg_ACLK : signal
        is "ASSOCIATED_RESET s_reg_RESETN_i, " &
           "ASSOCIATED_BUSIF s_reg";
    -- AR
    attribute X_INTERFACE_INFO of s_reg_ARADDR_i : signal
        is "xilinx.com:interface:aximm:1.0 s_reg ARADDR";
    attribute X_INTERFACE_INFO of s_reg_ARVALID_i : signal
        is "xilinx.com:interface:aximm:1.0 s_reg ARVALID";
    attribute X_INTERFACE_INFO of s_reg_ARREADY_o : signal
        is "xilinx.com:interface:aximm:1.0 s_reg ARREADY";
    attribute X_INTERFACE_INFO of s_reg_AWADDR_i : signal
        is "xilinx.com:interface:aximm:1.0 s_reg AWADDR";
    -- AW
    attribute X_INTERFACE_INFO of s_reg_AWVALID_i : signal
        is "xilinx.com:interface:aximm:1.0 s_reg AWVALID";
    attribute X_INTERFACE_INFO of s_reg_AWREADY_o : signal
        is "xilinx.com:interface:aximm:1.0 s_reg AWREADY";
    attribute X_INTERFACE_INFO of s_reg_BRESP_o : signal
        is "xilinx.com:interface:aximm:1.0 s_reg BRESP";
    -- B
    attribute X_INTERFACE_INFO of s_reg_BVALID_o : signal
        is "xilinx.com:interface:aximm:1.0 s_reg BVALID";
    attribute X_INTERFACE_INFO of s_reg_BREADY_i : signal
        is "xilinx.com:interface:aximm:1.0 s_reg BREADY";
    attribute X_INTERFACE_INFO of s_reg_RDATA_o : signal
        is "xilinx.com:interface:aximm:1.0 s_reg RDATA";
    -- R
    attribute X_INTERFACE_INFO of s_reg_RRESP_o : signal
        is "xilinx.com:interface:aximm:1.0 s_reg RRESP";
    attribute X_INTERFACE_INFO of s_reg_RVALID_o : signal
        is "xilinx.com:interface:aximm:1.0 s_reg RVALID";
    attribute X_INTERFACE_INFO of s_reg_RREADY_i : signal
        is "xilinx.com:interface:aximm:1.0 s_reg RREADY";
    -- W
    attribute X_INTERFACE_INFO of s_reg_WDATA_i : signal
        is "xilinx.com:interface:aximm:1.0 s_reg WDATA";
    attribute X_INTERFACE_INFO of s_reg_WSTRB_i : signal
        is "xilinx.com:interface:aximm:1.0 s_reg WSTRB";
    attribute X_INTERFACE_INFO of s_reg_WVALID_i : signal
        is "xilinx.com:interface:aximm:1.0 s_reg WVALID";
    attribute X_INTERFACE_INFO of s_reg_WREADY_o : signal
        is "xilinx.com:interface:aximm:1.0 s_reg WREADY";


    -- AXI slave interface to memory
    --
    attribute X_INTERFACE_INFO of s_axi_ACLK : signal
        is "xilinx.com:signal:clock:1.0 s_axi_ACLK clk";
    attribute X_INTERFACE_INFO of s_axi_RESETN_i : signal
        is "xilinx.com:signal:reset:1.0 s_axi_RESETN_i rst";
    attribute X_INTERFACE_PARAMETER of s_axi_ACLK : signal
        is "ASSOCIATED_RESET s_axi_RESETN_i, " &
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
    --
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
        AXI_FREQUENCY => AXI_FREQUENCY * 1.0,
        REG_FREQUENCY => REG_FREQUENCY * 1.0,
        CK_FREQUENCY => CK_FREQUENCY * 1.0
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
    axi_stats_o <= (
        0 => axi_stats.write_frame_error,
        1 => axi_stats.write_crc_error,
        2 => axi_stats.write_last_error,
        3 => axi_stats.write_address,
        4 => axi_stats.write_transfer,
        5 => axi_stats.write_data_beat,
        6 => axi_stats.read_frame_error,
        7 => axi_stats.read_crc_error,
        8 => axi_stats.read_address,
        9 => axi_stats.read_transfer,
        10 => axi_stats.read_data_beat
    );
end;
