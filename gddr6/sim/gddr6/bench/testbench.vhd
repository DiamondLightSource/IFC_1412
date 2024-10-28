library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_axi_defs.all;

entity testbench is
end testbench;

architecture arch of testbench is
    signal s_reg_ACLK : std_ulogic;
    signal s_reg_ARADDR : std_ulogic_vector(11 downto 0);
    signal s_reg_ARVALID : std_ulogic;
    signal s_reg_ARREADY : std_ulogic;
    signal s_reg_AWADDR : std_ulogic_vector(11 downto 0);
    signal s_reg_AWVALID : std_ulogic;
    signal s_reg_AWREADY : std_ulogic;
    signal s_reg_BRESP : std_ulogic_vector(1 downto 0);
    signal s_reg_BVALID : std_ulogic;
    signal s_reg_BREADY : std_ulogic;
    signal s_reg_RDATA : std_ulogic_vector(31 downto 0);
    signal s_reg_RRESP : std_ulogic_vector(1 downto 0);
    signal s_reg_RVALID : std_ulogic;
    signal s_reg_RREADY : std_ulogic;
    signal s_reg_WDATA : std_ulogic_vector(31 downto 0);
    signal s_reg_WSTRB : std_ulogic_vector(3 downto 0);
    signal s_reg_WVALID : std_ulogic;
    signal s_reg_WREADY : std_ulogic;

    signal s_axi_ACLK : std_logic := '0';
    signal s_axi_AWID : std_logic_vector(3 downto 0);
    signal s_axi_AWADDR : std_logic_vector(31 downto 0);
    signal s_axi_AWLEN : std_logic_vector(7 downto 0);
    signal s_axi_AWSIZE : std_logic_vector(2 downto 0);
    signal s_axi_AWBURST : std_logic_vector(1 downto 0);
    signal s_axi_AWLOCK : std_logic;
    signal s_axi_AWCACHE : std_logic_vector(3 downto 0);
    signal s_axi_AWPROT : std_logic_vector(2 downto 0);
    signal s_axi_AWQOS : std_logic_vector(3 downto 0);
    signal s_axi_AWUSER : std_logic_vector(3 downto 0);
    signal s_axi_AWVALID : std_logic := '0';
    signal s_axi_AWREADY : std_logic;
    signal s_axi_WDATA : std_logic_vector(511 downto 0);
    signal s_axi_WSTRB : std_logic_vector(63 downto 0);
    signal s_axi_WLAST : std_logic;
    signal s_axi_WVALID : std_logic := '0';
    signal s_axi_WREADY : std_logic;
    signal s_axi_BREADY : std_logic := '0';
    signal s_axi_BID : std_logic_vector(3 downto 0);
    signal s_axi_BRESP : std_logic_vector(1 downto 0);
    signal s_axi_BVALID : std_logic;
    signal s_axi_ARID : std_logic_vector(3 downto 0);
    signal s_axi_ARADDR : std_logic_vector(31 downto 0);
    signal s_axi_ARLEN : std_logic_vector(7 downto 0);
    signal s_axi_ARSIZE : std_logic_vector(2 downto 0);
    signal s_axi_ARBURST : std_logic_vector(1 downto 0);
    signal s_axi_ARLOCK : std_logic;
    signal s_axi_ARCACHE : std_logic_vector(3 downto 0);
    signal s_axi_ARPROT : std_logic_vector(2 downto 0);
    signal s_axi_ARQOS : std_logic_vector(3 downto 0);
    signal s_axi_ARUSER : std_logic_vector(3 downto 0);
    signal s_axi_ARVALID : std_logic := '0';
    signal s_axi_ARREADY : std_logic := '0';
    signal s_axi_RREADY : std_logic := '0';
    signal s_axi_RLAST : std_logic;
    signal s_axi_RVALID : std_logic;
    signal s_axi_RRESP : std_logic_vector(1 downto 0);
    signal s_axi_RID : std_logic_vector(3 downto 0);
    signal s_axi_RDATA : std_logic_vector(511 downto 0);

    signal axi_stats : std_ulogic_vector(0 to 10);

    signal pad_SG1_RESET_N : std_logic;
    signal pad_SG2_RESET_N : std_logic;
    signal pad_SG12_CKE_N : std_logic;
    signal pad_SG12_CK_P : std_logic;
    signal pad_SG12_CK_N : std_logic;
    signal pad_SG12_CABI_N : std_logic;
    signal pad_SG12_CAL : std_logic_vector(2 downto 0);
    signal pad_SG1_CA3_A : std_logic;
    signal pad_SG1_CA3_B : std_logic;
    signal pad_SG2_CA3_A : std_logic;
    signal pad_SG2_CA3_B : std_logic;
    signal pad_SG12_CAU : std_logic_vector(9 downto 4);
    signal pad_SG1_WCK_P : std_logic;
    signal pad_SG1_WCK_N : std_logic;
    signal pad_SG1_DQ_A : std_logic_vector(15 downto 0);
    signal pad_SG1_DBI_N_A : std_logic_vector(1 downto 0);
    signal pad_SG1_EDC_A : std_logic_vector(1 downto 0);
    signal pad_SG1_DQ_B : std_logic_vector(15 downto 0);
    signal pad_SG1_DBI_N_B : std_logic_vector(1 downto 0);
    signal pad_SG1_EDC_B : std_logic_vector(1 downto 0);
    signal pad_SG2_WCK_P : std_logic;
    signal pad_SG2_WCK_N : std_logic;
    signal pad_SG2_DQ_A : std_logic_vector(15 downto 0);
    signal pad_SG2_DBI_N_A : std_logic_vector(1 downto 0);
    signal pad_SG2_EDC_A : std_logic_vector(1 downto 0);
    signal pad_SG2_DQ_B : std_logic_vector(15 downto 0);
    signal pad_SG2_DBI_N_B : std_logic_vector(1 downto 0);
    signal pad_SG2_EDC_B : std_logic_vector(1 downto 0);

begin
    s_reg_ACLK <= not s_reg_ACLK after 2 ns;
    s_axi_ACLK <= not s_axi_ACLK after 2.3 ns;

    gddr6 : entity work.gddr6_ip port map (
        s_reg_ACLK => s_reg_ACLK,
        s_reg_ARADDR_i => s_reg_ARADDR,
        s_reg_ARVALID_i => s_reg_ARVALID,
        s_reg_ARREADY_o => s_reg_ARREADY,
        s_reg_AWADDR_i => s_reg_AWADDR,
        s_reg_AWVALID_i => s_reg_AWVALID,
        s_reg_AWREADY_o => s_reg_AWREADY,
        s_reg_BRESP_o => s_reg_BRESP,
        s_reg_BVALID_o => s_reg_BVALID,
        s_reg_BREADY_i => s_reg_BREADY,
        s_reg_RDATA_o => s_reg_RDATA,
        s_reg_RRESP_o => s_reg_RRESP,
        s_reg_RVALID_o => s_reg_RVALID,
        s_reg_RREADY_i => s_reg_RREADY,
        s_reg_WDATA_i => s_reg_WDATA,
        s_reg_WSTRB_i => s_reg_WSTRB,
        s_reg_WVALID_i => s_reg_WVALID,
        s_reg_WREADY_o => s_reg_WREADY,

        s_axi_ACLK => s_axi_ACLK,
        s_axi_AWID_i => s_axi_AWID,
        s_axi_AWADDR_i => s_axi_AWADDR,
        s_axi_AWLEN_i => s_axi_AWLEN,
        s_axi_AWSIZE_i => s_axi_AWSIZE,
        s_axi_AWBURST_i => s_axi_AWBURST,
        s_axi_AWLOCK_i => s_axi_AWLOCK,
        s_axi_AWCACHE_i => s_axi_AWCACHE,
        s_axi_AWPROT_i => s_axi_AWPROT,
        s_axi_AWQOS_i => s_axi_AWQOS,
        s_axi_AWUSER_i => s_axi_AWUSER,
        s_axi_AWVALID_i => s_axi_AWVALID,
        s_axi_AWREADY_o => s_axi_AWREADY,
        s_axi_WDATA_i => s_axi_WDATA,
        s_axi_WSTRB_i => s_axi_WSTRB,
        s_axi_WLAST_i => s_axi_WLAST,
        s_axi_WVALID_i => s_axi_WVALID,
        s_axi_WREADY_o => s_axi_WREADY,
        s_axi_BREADY_i => s_axi_BREADY,
        s_axi_BID_o => s_axi_BID,
        s_axi_BRESP_o => s_axi_BRESP,
        s_axi_BVALID_o => s_axi_BVALID,
        s_axi_ARID_i => s_axi_ARID,
        s_axi_ARADDR_i => s_axi_ARADDR,
        s_axi_ARLEN_i => s_axi_ARLEN,
        s_axi_ARSIZE_i => s_axi_ARSIZE,
        s_axi_ARBURST_i => s_axi_ARBURST,
        s_axi_ARLOCK_i => s_axi_ARLOCK,
        s_axi_ARCACHE_i => s_axi_ARCACHE,
        s_axi_ARPROT_i => s_axi_ARPROT,
        s_axi_ARQOS_i => s_axi_ARQOS,
        s_axi_ARUSER_i => s_axi_ARUSER,
        s_axi_ARVALID_i => s_axi_ARVALID,
        s_axi_ARREADY_o => s_axi_ARREADY,
        s_axi_RREADY_i => s_axi_RREADY,
        s_axi_RLAST_o => s_axi_RLAST,
        s_axi_RVALID_o => s_axi_RVALID,
        s_axi_RRESP_o => s_axi_RRESP,
        s_axi_RID_o => s_axi_RID,
        s_axi_RDATA_o => s_axi_RDATA,

        axi_stats_o => axi_stats,

        pad_SG1_RESET_N_o => pad_SG1_RESET_N,
        pad_SG2_RESET_N_o => pad_SG2_RESET_N,
        pad_SG12_CKE_N_o => pad_SG12_CKE_N,
        pad_SG12_CK_P_i => pad_SG12_CK_P,
        pad_SG12_CK_N_i => pad_SG12_CK_N,
        pad_SG12_CABI_N_o => pad_SG12_CABI_N,
        pad_SG12_CAL_o => pad_SG12_CAL,
        pad_SG1_CA3_A_o => pad_SG1_CA3_A,
        pad_SG1_CA3_B_o => pad_SG1_CA3_B,
        pad_SG2_CA3_A_o => pad_SG2_CA3_A,
        pad_SG2_CA3_B_o => pad_SG2_CA3_B,
        pad_SG12_CAU_o => pad_SG12_CAU,
        pad_SG1_WCK_P_i => pad_SG1_WCK_P,
        pad_SG1_WCK_N_i => pad_SG1_WCK_N,
        pad_SG1_DQ_A_io => pad_SG1_DQ_A,
        pad_SG1_DBI_N_A_io => pad_SG1_DBI_N_A,
        pad_SG1_EDC_A_io => pad_SG1_EDC_A,
        pad_SG1_DQ_B_io => pad_SG1_DQ_B,
        pad_SG1_DBI_N_B_io => pad_SG1_DBI_N_B,
        pad_SG1_EDC_B_io => pad_SG1_EDC_B,
        pad_SG2_WCK_P_i => pad_SG2_WCK_P,
        pad_SG2_WCK_N_i => pad_SG2_WCK_N,
        pad_SG2_DQ_A_io => pad_SG2_DQ_A,
        pad_SG2_DBI_N_A_io => pad_SG2_DBI_N_A,
        pad_SG2_EDC_A_io => pad_SG2_EDC_A,
        pad_SG2_DQ_B_io => pad_SG2_DQ_B,
        pad_SG2_DBI_N_B_io => pad_SG2_DBI_N_B,
        pad_SG2_EDC_B_io => pad_SG2_EDC_B
    );

    -- Assign sensible defaults
    -- Register interface
    s_reg_ARVALID <= '0';
    s_reg_AWVALID <= '0';
    s_reg_BREADY <= '1';
    s_reg_RREADY <= '1';
    s_reg_WVALID <= '0';
    -- Memory interface
    s_axi_ARVALID <= '0';
    s_axi_AWVALID <= '0';
    s_axi_BREADY <= '1';
    s_axi_RREADY <= '1';
    s_axi_WVALID <= '0';
    -- SG interface
    pad_SG12_CK_P <= '0';
    pad_SG12_CK_N <= '1';
    pad_SG1_WCK_P <= '0';
    pad_SG1_WCK_N <= '1';
    pad_SG2_WCK_P <= '0';
    pad_SG2_WCK_N <= '1';
    pad_SG1_DQ_A <= (others => 'H');
    pad_SG1_DBI_N_A <= (others => 'H');
    pad_SG1_EDC_A <= (others => 'H');
    pad_SG1_DQ_B <= (others => 'H');
    pad_SG1_DBI_N_B <= (others => 'H');
    pad_SG1_EDC_B <= (others => 'H');
    pad_SG2_DQ_A <= (others => 'H');
    pad_SG2_DBI_N_A <= (others => 'H');
    pad_SG2_EDC_A <= (others => 'H');
    pad_SG2_DQ_B <= (others => 'H');
    pad_SG2_DBI_N_B <= (others => 'H');
    pad_SG2_EDC_B <= (others => 'H');
end;
