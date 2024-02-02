-- Memory controller core

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_defs.all;

entity gddr6_ctrl is
    port (
        clk_i : in std_ulogic;

        -- Configuration and status connected to Setup
        ctrl_setup_i : in ctrl_setup_t;
        ctrl_status_o : out ctrl_status_t;

        -- Addresses are all 25 bits: 14 row select, 4 bank select, 7 column
        -- Lookahead addresses are 18 bits: row and bank only
        --
        -- Connection from AXI receiver
        -- WA Write Adddress
        axi_wa_address_i : in unsigned(24 downto 0);
        axi_wa_byte_mask_i : in std_ulogic_vector(127 downto 0);
        axi_wa_count_i : in unsigned(4 downto 0);
        axi_wa_valid_i : in std_ulogic;
        axi_wa_ready_o : out std_ulogic;
        -- WA Lookahead
        axi_wal_address_i : in unsigned(24 downto 0);
        axi_wal_valid_i : in std_ulogic;
        -- RA Read Address
        axi_ra_address_i : in unsigned(24 downto 0);
        axi_ra_count_i : in unsigned(4 downto 0);
        axi_ra_valid_i : in std_ulogic;
        axi_ra_ready_o : out std_ulogic;
        -- RA Lookahead
        axi_ral_address_i : in unsigned(24 downto 0);
        axi_ral_valid_i : in std_ulogic;
        -- WD Write Data
        axi_wd_data_i : in vector_array(63 downto 0)(7 downto 0);
        axi_wd_hold_o : out std_ulogic;
        axi_wd_ready_o : out std_ulogic;
        -- WR Write Response
        axi_wr_ok_o : out std_ulogic;
        axi_wr_ok_valid_o : out std_ulogic;
        -- RD Read Data
        axi_rd_data_o : out vector_array(63 downto 0)(7 downto 0);
        axi_rd_valid_o : out std_ulogic;
        axi_rd_ok_o : out std_ulogic;
        axi_rd_ok_valid_o : out std_ulogic;

        -- Connection to PHY (via Setup MUX)
        -- CA
        phy_ca_o : out vector_array(0 to 1)(9 downto 0);
        phy_ca3_o : out std_ulogic_vector(0 to 3);
        phy_cke_n_o : out std_ulogic_vector(0 to 1);
        -- DQ
        phy_output_enable_o : out std_ulogic;
        phy_data_o : out vector_array(63 downto 0)(7 downto 0);
        phy_data_i : in vector_array(63 downto 0)(7 downto 0);
        phy_edc_in_i : in vector_array(7 downto 0)(7 downto 0);
        phy_edc_write_i : in vector_array(7 downto 0)(7 downto 0);
        phy_edc_read_i : in vector_array(7 downto 0)(7 downto 0)
    );
end;

architecture arch of gddr6_ctrl is
begin
end;
