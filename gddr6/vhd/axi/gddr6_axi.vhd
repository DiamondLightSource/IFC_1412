-- Bridge between AXI and core controller

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gddr6_axi is
    port  (
        -- ---------------------------------------------------------------------
        -- AXI slave interface
        -- Clock and reset
        s_axi_ACLK_i : in std_logic;
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

        -- ---------------------------------------------------------------------
        -- Controller interface

        -- Connection from AXI receiver
        -- WA Write Adddress
        ctrl_wa_address_o : out unsigned(24 downto 0);
        ctrl_wa_byte_mask_o : out std_ulogic_vector(127 downto 0);
        ctrl_wa_count_o : out unsigned(4 downto 0);
        ctrl_wa_valid_o : out std_ulogic;
        ctrl_wa_ready_i : in std_ulogic;
        -- WA Lookahead
        ctrl_wal_address_o : out unsigned(24 downto 0);
        ctrl_wal_valid_o : out std_ulogic;
        -- RA Read Address
        ctrl_ra_address_o : out unsigned(24 downto 0);
        ctrl_ra_count_o : out unsigned(4 downto 0);
        ctrl_ra_valid_o : out std_ulogic;
        ctrl_ra_ready_i : in std_ulogic;
        -- RA Lookahead
        ctrl_ral_address_o : out unsigned(24 downto 0);
        ctrl_ral_valid_o : out std_ulogic;
        -- WD Write Data
        ctrl_wd_data_o : out std_ulogic_vector(511 downto 0);
        ctrl_wd_hold_i : in std_ulogic;
        ctrl_wd_ready_i : in std_ulogic;
        -- WR Write Response
        ctrl_wr_ok_i : in std_ulogic;
        ctrl_wr_ok_valid_i : in std_ulogic;
        -- RD Read Data
        ctrl_rd_data_i : in std_ulogic_vector(511 downto 0);
        ctrl_rd_valid_i : in std_ulogic
        ctrl_rd_ok_i : in std_ulogic;
        ctrl_rd_ok_valid_i : in std_ulogic;
    );
end;

architecture arch of gddr6_axi is
begin
end;
