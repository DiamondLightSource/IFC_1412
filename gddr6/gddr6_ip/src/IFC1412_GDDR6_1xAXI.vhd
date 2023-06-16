library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

entity IFC1412_GDDR6_1xAXI is
    generic (
        -- [1:0] : "11" : 4GB ,  "10" : 2GB,  "01" : 1GB,  "00" : 0.5GB
        g_axigddr6_WSIZ : std_logic_vector(1 downto 0):= "00";
        -- [1:0] : "11" : 512B , "10" : 256B, "01" : 128B, "00" : 64B
        g_axigddr6_WIDTH : std_logic_vector(1 downto 0):= "00";

        -- [1:0] : "00" : RBUF No Refill
        --       : "01" : RBUF Refill
        --       : "11" : RBUF Refill f(DPRAM Indexed in 1M/4M Page granularity
        -- [7:2] : Reserved
        g_axigddr6_READ : std_logic_vector(7 downto 0) := X"00";

        -- [0]   : '0' : Single WBUF used   '1':  Up to 16 Write transaction Posted
        -- [1]   :' 0' : Write Posted       :1.: AXI Ack only while data deposed  in GDD6
        -- [7:2] : Reserved
        g_axigddr6_WRITE : std_logic_vector(7 downto 0) := X"00"
    );

    port  (
        loc_INIT_RERUN : in std_logic_vector(1 downto 0):= "00";   -- [1:0] : "00" : Idle No action
                                                                                -- : "10" : PONFSM Init GDDR6 devices only
                                                                                -- : "11" : PONFSM Init LMK04616+GDDR6 devices
        loc_INIT_STATUS : out std_logic_vector(3 downto 0);          -- X"0" : Idle, X"1"->X"D" :inetermediate steps, X"F" : End_OK, X"F" : End_ERR

        eponfsm_RERUNo : out std_logic := '0';                                 -- Ext status  PONFSM microcode Execution
        eponfsm_SELo : out std_logic_vector(1 downto 0) := "01";             -- Ext status Microcode entry block (0x000-0x400-0x800-0xC00)
        eponfsm_STAo : out std_logic_vector(15 downto 0);                    -- Ext status PONFSM Execution Status [15] Busy
        eponfsm_RSTA_INo : out std_logic_vector(15 downto 2) := (others => '0'); -- Ext status Remote Conditionnal ESTA IN status
        eponfsm_RCTL_OUTo : out std_logic_vector(15 downto 0) := (others => '0'); -- Ext status Remote Synchronisation control

        -- ---------------------------------------------------------- --
        -- Back-end (TOP) TOP Services                                --
        -- ---------------------------------------------------------- --
        loc_SYSRESETn : in std_logic;
        loc_CLK100_REFA : in std_logic;
        loc_CLK100_REFB : in std_logic;

        loc_axi_EXTCLK : out std_logic;           -- Up level AXI support
        loc_axi_EXTRST : out std_logic;           -- Up level AXI support

        -- ---------------------------------------------------------- --
        -- GDDR6 Controller Control/Status/Debug support              --
        -- ---------------------------------------------------------- --
        gddr6_STATUS : out std_logic_vector(127 downto 0);

        -- ---------------------------------------------------------- --
        -- AXIL Master Port -> Access to LMK04616 Initialisation      --
        --      Refer to ....                                         --
        -- ---------------------------------------------------------- --
        pon_m_axil_ACLK : in std_logic;
        pon_m_axil_ARESET : in std_logic;

        pon_m_axil_AWADDR : out std_logic_vector(31 downto  0);
        pon_m_axil_AWPROT : out std_logic_vector( 2 downto  0);
        pon_m_axil_AWVALID : out std_logic;
        pon_m_axil_AWREADY : in std_logic;
        pon_m_axil_WDATA : out std_logic_vector(31 downto  0);
        pon_m_axil_WSTRB : out std_logic_vector( 3 downto  0);
        pon_m_axil_WVALID : out std_logic;
        pon_m_axil_WREADY : in std_logic;
        pon_m_axil_BRESP : in std_logic_vector( 1 downto  0);
        pon_m_axil_BVALID : in std_logic;
        pon_m_axil_BREADY : out std_logic;
        pon_m_axil_ARADDR : out std_logic_vector(31 downto  0);
        pon_m_axil_ARPROT : out std_logic_vector( 2 downto  0);
        pon_m_axil_ARVALID : out std_logic;
        pon_m_axil_ARREADY : in std_logic;
        pon_m_axil_RDATA : in std_logic_vector(31 downto  0);
        pon_m_axil_RRESP : in std_logic_vector( 1 downto  0);
        pon_m_axil_RVALID : in std_logic;
        pon_m_axil_RREADY : out std_logic;

        -- ---------------------------------------------------------- --
        -- AXIL Slave Port -> Mapping GDDR6 Controller TCSR resources --
        --   4KB Memory array AXIL -> TCSR Bridge                     --
        -- ---------------------------------------------------------- --
        s_axil_AWADDR_i : in std_logic_vector( 9 downto  0);
        s_axil_AWPROT_i : in std_logic_vector( 2 downto  0);
        s_axil_AWVALID_i : in std_logic;
        s_axil_AWREADY_o : out std_logic;
        s_axil_WDATA_i : in std_logic_vector(31 downto  0);
        s_axil_WSTRB_i : in std_logic_vector( 3 downto  0);
        s_axil_WVALID_i : in std_logic;
        s_axil_WREADY_o : out std_logic;
        s_axil_BRESP_o : out std_logic_vector( 1 downto  0);
        s_axil_BVALID_o : out std_logic;
        s_axil_BREADY_i : in std_logic;
        s_axil_ARADDR_i : in std_logic_vector( 9 downto  0);
        s_axil_ARPROT_i : in std_logic_vector( 2 downto  0);
        s_axil_ARVALID_i : in std_logic;
        s_axil_ARREADY_o : out std_logic;
        s_axil_RDATA_o : out std_logic_vector(31 downto  0);
        s_axil_RRESP_o : out std_logic_vector( 1 downto  0);
        s_axil_RVALID_o : out std_logic;
        s_axil_RREADY_i : in std_logic;

        -- ---------------------------------------------------------- --
        -- AXI4 Slave Port -> Mapping GDDR6 Memory Area               --
        --   1/2/4 GB Memory array AXI4 -> GDDR6                      --
        -- ---------------------------------------------------------- --
        gddr6_s_axi_ACLK_i : in std_logic;
        gddr6_s_axi_RESET_i : in std_logic;
        gddr6_s_axi_AWID_i : in std_logic_vector(3 downto 0);
        gddr6_s_axi_AWADDR_i : in std_logic_vector(31 downto 0);
        gddr6_s_axi_AWLEN_i : in std_logic_vector(7 downto 0);
        gddr6_s_axi_AWSIZE_i : in std_logic_vector(2 downto 0);
        gddr6_s_axi_AWBURST_i : in std_logic_vector(1 downto 0);
        gddr6_s_axi_AWLOCK_i : in std_logic;
        gddr6_s_axi_AWCACHE_i : in std_logic_vector(3 downto 0);
        gddr6_s_axi_AWPROT_i : in std_logic_vector(2 downto 0);
        gddr6_s_axi_AWQOS_i : in std_logic_vector(3 downto 0);
        gddr6_s_axi_AWUSER_i : in std_logic_vector(3 downto 0);
        gddr6_s_axi_AWVALID_i : in std_logic;
        gddr6_s_axi_AWREADY_o : out std_logic;
        gddr6_s_axi_WDATA_i : in std_logic_vector(511 downto 0);
        gddr6_s_axi_WSTRB_i : in std_logic_vector(63 downto 0);
        gddr6_s_axi_WLAST_i : in std_logic;
        gddr6_s_axi_WVALID_i : in std_logic;
        gddr6_s_axi_WREADY_o : out std_logic;
        gddr6_s_axi_BREADY_i : in std_logic;
        gddr6_s_axi_BID_o : out std_logic_vector(3 downto 0);
        gddr6_s_axi_BRESP_o : out std_logic_vector(1 downto 0);
        gddr6_s_axi_BVALID_o : out std_logic;
        gddr6_s_axi_ARID_i : in std_logic_vector(3 downto 0);
        gddr6_s_axi_ARADDR_i : in std_logic_vector(31 downto 0);
        gddr6_s_axi_ARLEN_i : in std_logic_vector(7 downto 0);
        gddr6_s_axi_ARSIZE_i : in std_logic_vector(2 downto 0);
        gddr6_s_axi_ARBURST_i : in std_logic_vector(1 downto 0);
        gddr6_s_axi_ARLOCK_i : in std_logic;
        gddr6_s_axi_ARCACHE_i : in std_logic_vector(3 downto 0);
        gddr6_s_axi_ARPROT_i : in std_logic_vector(2 downto 0);
        gddr6_s_axi_ARQOS_i : in std_logic_vector(3 downto 0);
        gddr6_s_axi_ARUSER_i : in std_logic_vector(3 downto 0);
        gddr6_s_axi_ARVALID_i : in std_logic;
        gddr6_s_axi_ARREADY_o : out std_logic;
        gddr6_s_axi_RREADY_i : in std_logic;
        gddr6_s_axi_RLAST_o : out std_logic;
        gddr6_s_axi_RVALID_o : out std_logic;
        gddr6_s_axi_RRESP_o : out std_logic_vector(1 downto 0);
        gddr6_s_axi_RID_o : out std_logic_vector(3 downto 0);
        gddr6_s_axi_RDATA_o : out std_logic_vector(511 downto 0);

        -- ---------------------------------------------------------- --
        -- GDDR6 PHY Interface                                        --
        -- ---------------------------------------------------------- --
        pad_SG1_RESET_N : out std_logic;
        pad_SG2_RESET_N : out std_logic;
        pad_SG12_CKE_N : out std_logic;
        pad_SG12_CK_P : in std_logic := '0';
        pad_SG12_CK_N : in std_logic := '1';

        pad_SG12_CABI_N : out std_logic;
        pad_SG12_CAL : out std_logic_vector( 2 downto 0);
        pad_SG1_CA3_A : out std_logic;
        pad_SG1_CA3_B : out std_logic;
        pad_SG2_CA3_A : out std_logic;
        pad_SG2_CA3_B : out std_logic;
        pad_SG12_CAU : out std_logic_vector( 9 downto 4);

        -- External incoming 1 GHz free running clock on WCK_t/WCK_c
        pad_SG1_WCK_P : in std_logic := '0';
        pad_SG1_WCK_N : in std_logic := '1';

        pad_SG1_DQ_A : inout std_logic_vector(15 downto 0);
        pad_SG1_DBI_N_A : inout std_logic_vector( 1 downto 0);
        pad_SG1_EDC_A : inout std_logic_vector( 1 downto 0);
        pad_SG1_DQ_B : inout std_logic_vector(15 downto 0);
        pad_SG1_DBI_N_B : inout std_logic_vector( 1 downto 0);
        pad_SG1_EDC_B : inout std_logic_vector( 1 downto 0);

        pad_SG2_WCK_P : in std_logic := '0';
        pad_SG2_WCK_N : in std_logic := '1';

        pad_SG2_DQ_A : inout std_logic_vector(15 downto 0);
        pad_SG2_DBI_N_A : inout std_logic_vector( 1 downto 0);
        pad_SG2_EDC_A : inout std_logic_vector( 1 downto 0);
        pad_SG2_DQ_B : inout std_logic_vector(15 downto 0);
        pad_SG2_DBI_N_B : inout std_logic_vector( 1 downto 0);
        pad_SG2_EDC_B : inout std_logic_vector( 1 downto 0)
    );
end entity IFC1412_GDDR6_1xAXI;

architecture rtl of IFC1412_GDDR6_1xAXI is

    attribute X_INTERFACE_INFO : string;
    attribute X_INTERFACE_PARAMETER : string;

    attribute X_INTERFACE_INFO of pon_m_axil_ACLK : signal
        is "xilinx.com:signal:clock:1.0 axil_clock clk";
    attribute X_INTERFACE_INFO of pon_m_axil_ARESET : signal
        is "xilinx.com:signal:reset:1.0 axil_reset rst";
    attribute X_INTERFACE_PARAMETER of pon_m_axil_ACLK : signal
        is "ASSOCIATED_RESET pon_m_axil_ARESET, " &
           "ASSOCIATED_BUSIF s_axil:pon_m_axil";

    attribute X_INTERFACE_INFO of gddr6_s_axi_ACLK_i : signal
        is "xilinx.com:signal:clock:1.0 axi_clock clk";
    attribute X_INTERFACE_INFO of gddr6_s_axi_RESET_i : signal
        is "xilinx.com:signal:reset:1.0 axi_reset rst";
    attribute X_INTERFACE_PARAMETER of gddr6_s_axi_ACLK_i : signal
        is "ASSOCIATED_RESET gddr6_s_axi_RESET_i, " &
           "ASSOCIATED_BUSIF gddr6_s_axi";

    attribute X_INTERFACE_INFO of s_axil_AWADDR_i   : signal
        is "xilinx.com:interface:aximm:1.0 s_axil AWADDR";
    attribute X_INTERFACE_INFO of s_axil_AWPROT_i   : signal
        is "xilinx.com:interface:aximm:1.0 s_axil AWPROT";
    attribute X_INTERFACE_INFO of s_axil_AWVALID_i  : signal
        is "xilinx.com:interface:aximm:1.0 s_axil AWVALID";
    attribute X_INTERFACE_INFO of s_axil_AWREADY_o  : signal
        is "xilinx.com:interface:aximm:1.0 s_axil AWREADY";
    attribute X_INTERFACE_INFO of s_axil_WDATA_i    : signal
        is "xilinx.com:interface:aximm:1.0 s_axil WDATA";
    attribute X_INTERFACE_INFO of s_axil_WSTRB_i    : signal
        is "xilinx.com:interface:aximm:1.0 s_axil WSTRB";
    attribute X_INTERFACE_INFO of s_axil_WVALID_i   : signal
        is "xilinx.com:interface:aximm:1.0 s_axil WVALID";
    attribute X_INTERFACE_INFO of s_axil_WREADY_o   : signal
        is "xilinx.com:interface:aximm:1.0 s_axil WREADY";
    attribute X_INTERFACE_INFO of s_axil_BRESP_o    : signal
        is "xilinx.com:interface:aximm:1.0 s_axil BRESP";
    attribute X_INTERFACE_INFO of s_axil_BVALID_o   : signal
        is "xilinx.com:interface:aximm:1.0 s_axil BVALID";
    attribute X_INTERFACE_INFO of s_axil_BREADY_i   : signal
        is "xilinx.com:interface:aximm:1.0 s_axil BREADY";
    attribute X_INTERFACE_INFO of s_axil_ARADDR_i   : signal
        is "xilinx.com:interface:aximm:1.0 s_axil ARADDR";
    attribute X_INTERFACE_INFO of s_axil_ARPROT_i   : signal
        is "xilinx.com:interface:aximm:1.0 s_axil ARPROT";
    attribute X_INTERFACE_INFO of s_axil_ARVALID_i  : signal
        is "xilinx.com:interface:aximm:1.0 s_axil ARVALID";
    attribute X_INTERFACE_INFO of s_axil_ARREADY_o  : signal
        is "xilinx.com:interface:aximm:1.0 s_axil ARREADY";
    attribute X_INTERFACE_INFO of s_axil_RDATA_o    : signal
        is "xilinx.com:interface:aximm:1.0 s_axil RDATA";
    attribute X_INTERFACE_INFO of s_axil_RRESP_o    : signal
        is "xilinx.com:interface:aximm:1.0 s_axil RRESP";
    attribute X_INTERFACE_INFO of s_axil_RVALID_o   : signal
        is "xilinx.com:interface:aximm:1.0 s_axil RVALID";
    attribute X_INTERFACE_INFO of s_axil_RREADY_i   : signal
        is "xilinx.com:interface:aximm:1.0 s_axil RREADY";

    attribute X_INTERFACE_INFO of gddr6_s_axi_AWID_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi AWID";
    attribute X_INTERFACE_INFO of gddr6_s_axi_AWADDR_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi AWADDR";
    attribute X_INTERFACE_INFO of gddr6_s_axi_AWLEN_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi AWLEN";
    attribute X_INTERFACE_INFO of gddr6_s_axi_AWSIZE_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi AWSIZE";
    attribute X_INTERFACE_INFO of gddr6_s_axi_AWBURST_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi AWBURST";
    attribute X_INTERFACE_INFO of gddr6_s_axi_AWLOCK_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi AWLOCK";
    attribute X_INTERFACE_INFO of gddr6_s_axi_AWCACHE_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi AWCACHE";
    attribute X_INTERFACE_INFO of gddr6_s_axi_AWPROT_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi AWPROT";
    attribute X_INTERFACE_INFO of gddr6_s_axi_AWQOS_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi AWQOS";
    attribute X_INTERFACE_INFO of gddr6_s_axi_AWUSER_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi AWUSER";
    attribute X_INTERFACE_INFO of gddr6_s_axi_AWVALID_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi AWVALID";
    attribute X_INTERFACE_INFO of gddr6_s_axi_AWREADY_o : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi AWREADY";
    attribute X_INTERFACE_INFO of gddr6_s_axi_WDATA_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi WDATA";
    attribute X_INTERFACE_INFO of gddr6_s_axi_WSTRB_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi WSTRB";
    attribute X_INTERFACE_INFO of gddr6_s_axi_WLAST_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi WLAST";
    attribute X_INTERFACE_INFO of gddr6_s_axi_WVALID_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi WVALID";
    attribute X_INTERFACE_INFO of gddr6_s_axi_WREADY_o : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi WREADY";
    attribute X_INTERFACE_INFO of gddr6_s_axi_BREADY_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi BREADY";
    attribute X_INTERFACE_INFO of gddr6_s_axi_BID_o : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi BID";
    attribute X_INTERFACE_INFO of gddr6_s_axi_BRESP_o : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi BRESP";
    attribute X_INTERFACE_INFO of gddr6_s_axi_BVALID_o : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi BVALID";
    attribute X_INTERFACE_INFO of gddr6_s_axi_ARID_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi ARID";
    attribute X_INTERFACE_INFO of gddr6_s_axi_ARADDR_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi ARADDR";
    attribute X_INTERFACE_INFO of gddr6_s_axi_ARLEN_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi ARLEN";
    attribute X_INTERFACE_INFO of gddr6_s_axi_ARSIZE_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi ARSIZE";
    attribute X_INTERFACE_INFO of gddr6_s_axi_ARBURST_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi ARBURST";
    attribute X_INTERFACE_INFO of gddr6_s_axi_ARLOCK_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi ARLOCK";
    attribute X_INTERFACE_INFO of gddr6_s_axi_ARCACHE_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi ARCACHE";
    attribute X_INTERFACE_INFO of gddr6_s_axi_ARPROT_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi ARPROT";
    attribute X_INTERFACE_INFO of gddr6_s_axi_ARQOS_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi ARQOS";
    attribute X_INTERFACE_INFO of gddr6_s_axi_ARUSER_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi ARUSER";
    attribute X_INTERFACE_INFO of gddr6_s_axi_ARVALID_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi ARVALID";
    attribute X_INTERFACE_INFO of gddr6_s_axi_ARREADY_o : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi ARREADY";
    attribute X_INTERFACE_INFO of gddr6_s_axi_RREADY_i : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi RREADY";
    attribute X_INTERFACE_INFO of gddr6_s_axi_RLAST_o : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi RLAST";
    attribute X_INTERFACE_INFO of gddr6_s_axi_RVALID_o : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi RVALID";
    attribute X_INTERFACE_INFO of gddr6_s_axi_RRESP_o : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi RRESP";
    attribute X_INTERFACE_INFO of gddr6_s_axi_RID_o : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi RID";
    attribute X_INTERFACE_INFO of gddr6_s_axi_RDATA_o : signal
        is "xilinx.com:interface:aximm:1.0 gddr6_s_axi RDATA";

    attribute X_INTERFACE_INFO of eponfsm_RERUNo    : signal
        is "ioxos.ch:gddr6if:ponsfm:0.0 eponfsm RERUN";
    attribute X_INTERFACE_INFO of eponfsm_SELo      : signal
        is "ioxos.ch:gddr6if:ponsfm:0.0 eponfsm SEL";
    attribute X_INTERFACE_INFO of eponfsm_STAo      : signal
        is "ioxos.ch:gddr6if:ponsfm:0.0 eponfsm STA";
    attribute X_INTERFACE_INFO of eponfsm_RSTA_INo  : signal
        is "ioxos.ch:gddr6if:ponsfm:0.0 eponfsm RSTA_IN";
    attribute X_INTERFACE_INFO of eponfsm_RCTL_OUTo : signal
        is "ioxos.ch:gddr6if:ponsfm:0.0 eponfsm RCTL_OUT";

    attribute X_INTERFACE_INFO of pad_SG1_RESET_N : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG1_RESET_N";
    attribute X_INTERFACE_INFO of pad_SG2_RESET_N : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG2_RESET_N";
    attribute X_INTERFACE_INFO of pad_SG12_CKE_N : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG12_CKE_N";
    attribute X_INTERFACE_INFO of pad_SG12_CK_P : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG12_CK_P";
    attribute X_INTERFACE_INFO of pad_SG12_CK_N : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG12_CK_N";
    attribute X_INTERFACE_INFO of pad_SG12_CABI_N : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG12_CABI_N";
    attribute X_INTERFACE_INFO of pad_SG12_CAL : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG12_CAL";
    attribute X_INTERFACE_INFO of pad_SG1_CA3_A : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG1_CA3_A";
    attribute X_INTERFACE_INFO of pad_SG1_CA3_B : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG1_CA3_B";
    attribute X_INTERFACE_INFO of pad_SG2_CA3_A : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG2_CA3_A";
    attribute X_INTERFACE_INFO of pad_SG2_CA3_B : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG2_CA3_B";
    attribute X_INTERFACE_INFO of pad_SG12_CAU : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG12_CAU";
    attribute X_INTERFACE_INFO of pad_SG1_WCK_P : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG1_WCK_P";
    attribute X_INTERFACE_INFO of pad_SG1_WCK_N : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG1_WCK_N";
    attribute X_INTERFACE_INFO of pad_SG1_DQ_A : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG1_DQ_A";
    attribute X_INTERFACE_INFO of pad_SG1_DBI_N_A : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG1_DBI_N_A";
    attribute X_INTERFACE_INFO of pad_SG1_EDC_A : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG1_EDC_A";
    attribute X_INTERFACE_INFO of pad_SG1_DQ_B : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG1_DQ_B";
    attribute X_INTERFACE_INFO of pad_SG1_DBI_N_B : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG1_DBI_N_B";
    attribute X_INTERFACE_INFO of pad_SG1_EDC_B : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG1_EDC_B";
    attribute X_INTERFACE_INFO of pad_SG2_WCK_P : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG2_WCK_P";
    attribute X_INTERFACE_INFO of pad_SG2_WCK_N : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG2_WCK_N";
    attribute X_INTERFACE_INFO of pad_SG2_DQ_A : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG2_DQ_A";
    attribute X_INTERFACE_INFO of pad_SG2_DBI_N_A : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG2_DBI_N_A";
    attribute X_INTERFACE_INFO of pad_SG2_EDC_A : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG2_EDC_A";
    attribute X_INTERFACE_INFO of pad_SG2_DQ_B : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG2_DQ_B";
    attribute X_INTERFACE_INFO of pad_SG2_DBI_N_B : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG2_DBI_N_B";
    attribute X_INTERFACE_INFO of pad_SG2_EDC_B : signal
        is "ioxos.ch:gddr6if:gddr6:0.0 gddr6 SG2_EDC_B";

begin
end;
