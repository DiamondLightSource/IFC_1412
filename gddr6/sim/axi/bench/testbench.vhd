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

    signal axi_request : axi_request_t := IDLE_AXI_REQUEST;
    signal axi_response : axi_response_t;
    signal axi_stats : axi_stats_t;

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
        axi_request_i => axi_request,
        axi_response_o => axi_response,
        axi_stats_o => axi_stats,

        ck_clk_i => ck_clk,
        ctrl_read_request_o => ctrl_read_request,
        ctrl_read_response_i => ctrl_read_response,
        ctrl_write_request_o => ctrl_write_request,
        ctrl_write_response_i => ctrl_write_response
    );
end;
