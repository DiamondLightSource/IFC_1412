-- Wraps axi_{request,response} master to AXI slave interface
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;

entity axi_master_wrapper is
    port (
        -- AR
        s_axi_araddr_o : out std_logic_vector(31 downto 0);
        s_axi_arburst_o : out std_logic_vector(1 downto 0);
        s_axi_arcache_o : out std_logic_vector(3 downto 0);
        s_axi_arid_o : out std_logic_vector(3 downto 0);
        s_axi_arlen_o : out std_logic_vector(7 downto 0);
        s_axi_arlock_o : out std_logic;
        s_axi_arprot_o : out std_logic_vector(2 downto 0);
        s_axi_arqos_o : out std_logic_vector(3 downto 0);
        s_axi_arready_i : in std_logic;
        s_axi_arsize_o : out std_logic_vector(2 downto 0);
        s_axi_arvalid_o : out std_logic;
        -- R
        s_axi_rdata_i : in std_logic_vector(511 downto 0);
        s_axi_rid_i : in std_logic_vector(3 downto 0);
        s_axi_rlast_i : in std_logic;
        s_axi_rready_o : out std_logic;
        s_axi_rresp_i : in std_logic_vector(1 downto 0);
        s_axi_rvalid_i : in std_logic;
        -- AW
        s_axi_awaddr_o : out std_logic_vector(31 downto 0);
        s_axi_awburst_o : out std_logic_vector(1 downto 0);
        s_axi_awcache_o : out std_logic_vector(3 downto 0);
        s_axi_awid_o : out std_logic_vector(3 downto 0);
        s_axi_awlen_o : out std_logic_vector(7 downto 0);
        s_axi_awlock_o : out std_logic;
        s_axi_awprot_o : out std_logic_vector(2 downto 0);
        s_axi_awqos_o : out std_logic_vector(3 downto 0);
        s_axi_awready_i : in std_logic;
        s_axi_awsize_o : out std_logic_vector(2 downto 0);
        s_axi_awvalid_o : out std_logic;
        -- W
        s_axi_wdata_o : out std_logic_vector(511 downto 0);
        s_axi_wlast_o : out std_logic;
        s_axi_wready_i : in std_logic;
        s_axi_wstrb_o : out std_logic_vector(63 downto 0);
        s_axi_wvalid_o : out std_logic;
        -- B
        s_axi_bid_i : in std_logic_vector(3 downto 0);
        s_axi_bready_o : out std_logic;
        s_axi_bresp_i : in std_logic_vector(1 downto 0);
        s_axi_bvalid_i : in std_logic;

        axi_request_i : in axi_request_t;
        axi_response_o : out axi_response_t
    );
end;

architecture arch of axi_master_wrapper is
begin
    -- AW
    s_axi_awaddr_o  <= std_ulogic_vector(axi_request_i.write_address.addr);
    s_axi_awburst_o <= axi_request_i.write_address.burst;
    s_axi_awcache_o <= "0110";          -- Write-through no-allocate caching
    s_axi_awid_o    <= axi_request_i.write_address.id;
    s_axi_awlen_o   <= std_ulogic_vector(axi_request_i.write_address.len);
    s_axi_awlock_o  <= '0';             -- No locking
    s_axi_awprot_o  <= "010";           -- Unprivileged non-secure data access
    s_axi_awqos_o   <= "0000";          -- Default QoS
    s_axi_awsize_o  <= std_ulogic_vector(axi_request_i.write_address.size);
    s_axi_awvalid_o <= axi_request_i.write_address.valid;
    -- W
    s_axi_wdata_o   <= axi_request_i.write_data.data;
    s_axi_wstrb_o   <= axi_request_i.write_data.strb;
    s_axi_wlast_o   <= axi_request_i.write_data.last;
    s_axi_wvalid_o  <= axi_request_i.write_data.valid;
    -- B
    s_axi_bready_o  <= axi_request_i.write_response_ready;
    -- AR
    s_axi_araddr_o  <= std_ulogic_vector(axi_request_i.read_address.addr);
    s_axi_arburst_o <= axi_request_i.read_address.burst;
    s_axi_arcache_o <= "0110";          -- Write-through no-allocate caching
    s_axi_arid_o    <= axi_request_i.read_address.id;
    s_axi_arlen_o   <= std_ulogic_vector(axi_request_i.read_address.len);
    s_axi_arlock_o  <= '0';             -- No locking
    s_axi_arprot_o  <= "010";           -- Unprivileged non-secure data access
    s_axi_arqos_o   <= "0000";          -- Default QoS
    s_axi_arsize_o  <= std_ulogic_vector(axi_request_i.read_address.size);
    s_axi_arvalid_o <= axi_request_i.read_address.valid;
    -- R
    s_axi_rready_o  <= axi_request_i.read_data_ready;

    axi_response_o <= (
        -- AW
        write_address_ready => s_axi_awready_i,
        -- W
        write_data_ready => s_axi_wready_i,
        -- B
        write_response => (
            id => s_axi_bid_i,
            resp => s_axi_bresp_i,
            valid => s_axi_bvalid_i
        ),
        -- AR
        read_address_ready => s_axi_arready_i,
        -- R
        read_data => (
            id => s_axi_rid_i,
            data => s_axi_rdata_i,
            resp => s_axi_rresp_i,
            last => s_axi_rlast_i,
            valid => s_axi_rvalid_i
        )
    );
end;
