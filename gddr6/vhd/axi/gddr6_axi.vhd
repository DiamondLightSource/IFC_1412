-- Bridge between AXI and core controller

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gddr6_axi is
    port  (
        -- The AXI slave interface is on axi_clk_i and is bridged within this
        -- component to the SG controller on ck_clk_i
        axi_clk_i : in std_ulogic;

        -- WA
        axi_wa_i : in axi_write_address_t;
        axi_wa_ready_o : out std_ulogic;
        -- W
        axi_w_i : in axi_write_data_t;
        axi_w_ready_o : out std_ulogic;
        -- B
        axi_b_o : out axi_write_response_t;
        axi_b_ready_i : in std_ulogic;
        -- RA
        axi_ra_i : in axi_read_address_t;
        axi_ra_ready_o : out std_ulogic;
        -- R
        axi_r_o : out axi_read_data_t;
        axi_r_ready_o : in std_ulogic;

        -- ---------------------------------------------------------------------
        -- Controller interface on CK clk

        ck_clk_i : in std_ulogic;

        -- Connection to CTRL
        ctrl_read_request_o : out axi_ctrl_read_request_t;
        ctrl_read_response_i : in axi_ctrl_read_response_t;
        ctrl_write_request_o : out axi_ctrl_write_request_t;
        ctrl_write_response_i : in axi_ctrl_write_response_t
    );
end;

architecture arch of gddr6_axi is
begin
end;
