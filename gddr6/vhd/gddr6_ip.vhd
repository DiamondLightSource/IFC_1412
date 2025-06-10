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

entity gddr6_ip is
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


        -- Asynchronous trigger to capture SG activity.  Triggering is on the
        -- rising edge of this signal which must be held high for more than two
        -- REG_FREQUENCY ticks.
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

    -- Interface parameters.  It's not terribly clear what the role of these
    -- parameters is, but they are documented in PG373 as part of the AXI
    -- Register Slice documentation, so it seems to make sense to provide these.
    attribute X_INTERFACE_PARAMETER of s_axi_ARADDR_i : signal
        is "XIL_INTERFACENAME s_axi, " &
           "NUM_READ_OUTSTANDING 64, " &    -- Depth of address FIFOs
           "NUM_WRITE_OUTSTANDING 64, " &
           "SUPPORTS_NARROW_BURST 1, " &    -- Yes, we support weird bursts
           "HAS_BURST 0, " &                -- Only INCR bursts supported
           "MAX_BURST_LENGTH 256";          -- (Only with narrow bursts)


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


    -- This must be an exact copy of the gddr6_ip_netlist entity declaration
    component gddr6_ip_netlist is
        port (
            s_reg_ACLK : in std_ulogic;
            s_reg_RESETN_i : in std_ulogic := '1';
            s_reg_ARADDR_i : in std_ulogic_vector(11 downto 0);
            s_reg_ARVALID_i : in std_ulogic;
            s_reg_ARREADY_o : out std_ulogic;
            s_reg_AWADDR_i : in std_ulogic_vector(11 downto 0);
            s_reg_AWVALID_i : in std_ulogic;
            s_reg_AWREADY_o : out std_ulogic;
            s_reg_BRESP_o : out std_ulogic_vector(1 downto 0);
            s_reg_BVALID_o : out std_ulogic;
            s_reg_BREADY_i : in std_ulogic;
            s_reg_RDATA_o : out std_ulogic_vector(31 downto 0);
            s_reg_RRESP_o : out std_ulogic_vector(1 downto 0);
            s_reg_RVALID_o : out std_ulogic;
            s_reg_RREADY_i : in std_ulogic;
            s_reg_WDATA_i : in std_ulogic_vector(31 downto 0);
            s_reg_WSTRB_i : in std_ulogic_vector(3 downto 0);
            s_reg_WVALID_i : in std_ulogic;
            s_reg_WREADY_o : out std_ulogic;

            setup_trigger_i : in std_ulogic := '0';

            s_axi_ACLK : in std_logic;
            s_axi_RESETN_i : in std_ulogic := '1';
            s_axi_AWID_i : in std_logic_vector(3 downto 0);
            s_axi_AWADDR_i : in std_logic_vector(31 downto 0);
            s_axi_AWLEN_i : in std_logic_vector(7 downto 0);
            s_axi_AWSIZE_i : in std_logic_vector(2 downto 0);
            s_axi_AWBURST_i : in std_logic_vector(1 downto 0);
            s_axi_AWVALID_i : in std_logic;
            s_axi_AWREADY_o : out std_logic;
            s_axi_WDATA_i : in std_logic_vector(511 downto 0);
            s_axi_WSTRB_i : in std_logic_vector(63 downto 0);
            s_axi_WLAST_i : in std_logic;
            s_axi_WVALID_i : in std_logic;
            s_axi_WREADY_o : out std_logic;
            s_axi_BREADY_i : in std_logic;
            s_axi_BID_o : out std_logic_vector(3 downto 0);
            s_axi_BRESP_o : out std_logic_vector(1 downto 0);
            s_axi_BVALID_o : out std_logic;
            s_axi_ARID_i : in std_logic_vector(3 downto 0);
            s_axi_ARADDR_i : in std_logic_vector(31 downto 0);
            s_axi_ARLEN_i : in std_logic_vector(7 downto 0);
            s_axi_ARSIZE_i : in std_logic_vector(2 downto 0);
            s_axi_ARBURST_i : in std_logic_vector(1 downto 0);
            s_axi_ARVALID_i : in std_logic;
            s_axi_ARREADY_o : out std_logic;
            s_axi_RREADY_i : in std_logic;
            s_axi_RLAST_o : out std_logic;
            s_axi_RVALID_o : out std_logic;
            s_axi_RRESP_o : out std_logic_vector(1 downto 0);
            s_axi_RID_o : out std_logic_vector(3 downto 0);
            s_axi_RDATA_o : out std_logic_vector(511 downto 0);

            axi_stats_o : out std_ulogic_vector(0 to 10);

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
    end component;

begin
    netlist : gddr6_ip_netlist port map (
        s_reg_ACLK => s_reg_ACLK,
        s_reg_RESETN_i => s_reg_RESETN_i,
        s_reg_ARADDR_i => s_reg_ARADDR_i,
        s_reg_ARVALID_i => s_reg_ARVALID_i,
        s_reg_ARREADY_o => s_reg_ARREADY_o,
        s_reg_AWADDR_i => s_reg_AWADDR_i,
        s_reg_AWVALID_i => s_reg_AWVALID_i,
        s_reg_AWREADY_o => s_reg_AWREADY_o,
        s_reg_BRESP_o => s_reg_BRESP_o,
        s_reg_BVALID_o => s_reg_BVALID_o,
        s_reg_BREADY_i => s_reg_BREADY_i,
        s_reg_RDATA_o => s_reg_RDATA_o,
        s_reg_RRESP_o => s_reg_RRESP_o,
        s_reg_RVALID_o => s_reg_RVALID_o,
        s_reg_RREADY_i => s_reg_RREADY_i,
        s_reg_WDATA_i => s_reg_WDATA_i,
        s_reg_WSTRB_i => s_reg_WSTRB_i,
        s_reg_WVALID_i => s_reg_WVALID_i,
        s_reg_WREADY_o => s_reg_WREADY_o,

        setup_trigger_i => setup_trigger_i,

        s_axi_ACLK => s_axi_ACLK,
        s_axi_RESETN_i => s_axi_RESETN_i,
        s_axi_AWID_i => s_axi_AWID_i,
        s_axi_AWADDR_i => s_axi_AWADDR_i,
        s_axi_AWLEN_i => s_axi_AWLEN_i,
        s_axi_AWSIZE_i => s_axi_AWSIZE_i,
        s_axi_AWBURST_i => s_axi_AWBURST_i,
        s_axi_AWVALID_i => s_axi_AWVALID_i,
        s_axi_AWREADY_o => s_axi_AWREADY_o,
        s_axi_WDATA_i => s_axi_WDATA_i,
        s_axi_WSTRB_i => s_axi_WSTRB_i,
        s_axi_WLAST_i => s_axi_WLAST_i,
        s_axi_WVALID_i => s_axi_WVALID_i,
        s_axi_WREADY_o => s_axi_WREADY_o,
        s_axi_BREADY_i => s_axi_BREADY_i,
        s_axi_BID_o => s_axi_BID_o,
        s_axi_BRESP_o => s_axi_BRESP_o,
        s_axi_BVALID_o => s_axi_BVALID_o,
        s_axi_ARID_i => s_axi_ARID_i,
        s_axi_ARADDR_i => s_axi_ARADDR_i,
        s_axi_ARLEN_i => s_axi_ARLEN_i,
        s_axi_ARSIZE_i => s_axi_ARSIZE_i,
        s_axi_ARBURST_i => s_axi_ARBURST_i,
        s_axi_ARVALID_i => s_axi_ARVALID_i,
        s_axi_ARREADY_o => s_axi_ARREADY_o,
        s_axi_RREADY_i => s_axi_RREADY_i,
        s_axi_RLAST_o => s_axi_RLAST_o,
        s_axi_RVALID_o => s_axi_RVALID_o,
        s_axi_RRESP_o => s_axi_RRESP_o,
        s_axi_RID_o => s_axi_RID_o,
        s_axi_RDATA_o => s_axi_RDATA_o,

        axi_stats_o => axi_stats_o,

        pad_SG1_RESET_N_o => pad_SG1_RESET_N_o,
        pad_SG2_RESET_N_o => pad_SG2_RESET_N_o,
        pad_SG12_CKE_N_o => pad_SG12_CKE_N_o,
        pad_SG12_CK_P_i => pad_SG12_CK_P_i,
        pad_SG12_CK_N_i => pad_SG12_CK_N_i,
        pad_SG12_CABI_N_o => pad_SG12_CABI_N_o,
        pad_SG12_CAL_o => pad_SG12_CAL_o,
        pad_SG1_CA3_A_o => pad_SG1_CA3_A_o,
        pad_SG1_CA3_B_o => pad_SG1_CA3_B_o,
        pad_SG2_CA3_A_o => pad_SG2_CA3_A_o,
        pad_SG2_CA3_B_o => pad_SG2_CA3_B_o,
        pad_SG12_CAU_o => pad_SG12_CAU_o,
        pad_SG1_WCK_P_i => pad_SG1_WCK_P_i,
        pad_SG1_WCK_N_i => pad_SG1_WCK_N_i,
        pad_SG1_DQ_A_io => pad_SG1_DQ_A_io,
        pad_SG1_DBI_N_A_io => pad_SG1_DBI_N_A_io,
        pad_SG1_EDC_A_io => pad_SG1_EDC_A_io,
        pad_SG1_DQ_B_io => pad_SG1_DQ_B_io,
        pad_SG1_DBI_N_B_io => pad_SG1_DBI_N_B_io,
        pad_SG1_EDC_B_io => pad_SG1_EDC_B_io,
        pad_SG2_WCK_P_i => pad_SG2_WCK_P_i,
        pad_SG2_WCK_N_i => pad_SG2_WCK_N_i,
        pad_SG2_DQ_A_io => pad_SG2_DQ_A_io,
        pad_SG2_DBI_N_A_io => pad_SG2_DBI_N_A_io,
        pad_SG2_EDC_A_io => pad_SG2_EDC_A_io,
        pad_SG2_DQ_B_io => pad_SG2_DQ_B_io,
        pad_SG2_DBI_N_B_io => pad_SG2_DBI_N_B_io,
        pad_SG2_EDC_B_io => pad_SG2_EDC_B_io
    );
end;
