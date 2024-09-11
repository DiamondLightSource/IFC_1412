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
    constant AXI_PERIOD : time := 4.95 ns;
    constant CTRL_PERIOD : time := 4 ns;
    signal axi_clk : std_ulogic := '0';
    signal ck_clk : std_ulogic := '0';

    signal axi_wa : axi_address_t := IDLE_AXI_ADDRESS;
    signal axi_wa_ready : std_ulogic;
    signal axi_w : axi_write_data_t := IDLE_AXI_WRITE_DATA;
    signal axi_w_ready : std_ulogic;
    signal axi_b : axi_write_response_t;
    signal axi_b_ready : std_ulogic := '0';
    signal axi_ra : axi_address_t := IDLE_AXI_ADDRESS;
    signal axi_ra_ready : std_ulogic;
    signal axi_r : axi_read_data_t;
    signal axi_r_ready : std_ulogic := '0';

    signal ctrl_read_request : axi_ctrl_read_request_t;
    signal ctrl_read_response : axi_ctrl_read_response_t
        := IDLE_AXI_CTRL_READ_RESPONSE;
    signal ctrl_write_request : axi_ctrl_write_request_t;
    signal ctrl_write_response : axi_ctrl_write_response_t
        := IDLE_AXI_CTRL_WRITE_RESPONSE;

    -- Converts period in time units into the corresponding period in ns
    function period_to_mhz(period : time) return real is
    begin
        return 1.0e-3 * real(1 ms / period);
    end;

begin
    axi_clk <= not axi_clk after AXI_PERIOD / 2;
    ck_clk <= not ck_clk after CTRL_PERIOD / 2;

    axi : entity work.gddr6_axi generic map (
        AXI_FREQUENCY => period_to_mhz(AXI_PERIOD),
        CK_FREQUENCY => period_to_mhz(CTRL_PERIOD)
    ) port map (
        axi_clk_i => axi_clk,
        axi_wa_i => axi_wa,
        axi_wa_ready_o => axi_wa_ready,
        axi_w_i => axi_w,
        axi_w_ready_o => axi_w_ready,
        axi_b_o => axi_b,
        axi_b_ready_i => axi_b_ready,
        axi_ra_i => axi_ra,
        axi_ra_ready_o => axi_ra_ready,
        axi_r_o => axi_r,
        axi_r_ready_i => axi_r_ready,

        ck_clk_i => ck_clk,
        ctrl_read_request_o => ctrl_read_request,
        ctrl_read_response_i => ctrl_read_response,
        ctrl_write_request_o => ctrl_write_request,
        ctrl_write_response_i => ctrl_write_response
    );
end;
