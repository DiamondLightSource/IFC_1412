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

    -- AXI slave interface
    signal axi_wa : axi_address_t;
    signal axi_wa_ready : std_ulogic;
    signal axi_w : axi_write_data_t;
    signal axi_w_ready : std_ulogic;
    signal axi_b : axi_write_response_t;
    signal axi_b_ready : std_ulogic;
    signal axi_ra : axi_address_t;
    signal axi_ra_ready : std_ulogic;
    signal axi_r : axi_read_data_t;
    signal axi_r_ready : std_ulogic;

    -- Connection AXI<->CTRL
    signal read_request : axi_ctrl_read_request_t;
    signal read_response : axi_ctrl_read_response_t;
    signal write_request : axi_ctrl_write_request_t;
    signal write_response : axi_ctrl_write_response_t;

    -- CTRL config and monitoring
    signal ctrl_setup : ctrl_setup_t;
    signal ctrl_status : ctrl_status_t;

    -- Interface to PHY
    signal phy_ca : phy_ca_t;
    signal phy_dq_out : phy_dq_out_t;
    signal phy_dq_in : phy_dq_in_t;

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
        ctrl_read_request_o => read_request,
        ctrl_read_response_i => read_response,
        ctrl_write_request_o => write_request,
        ctrl_write_response_i => write_response
    );

    ctrl : entity work.gddr6_ctrl port map (
        clk_i => ck_clk,

        ctrl_setup_i => ctrl_setup,
        ctrl_status_o => ctrl_status,

        axi_read_request_i => read_request,
        axi_read_response_o => read_response,
        axi_write_request_i => write_request,
        axi_write_response_o => write_response,

        phy_ca_o => phy_ca,
        phy_dq_o => phy_dq_out,
        phy_dq_i => phy_dq_in
    );

    ctrl_setup <= (
        enable_refresh => '1',
        priority_mode => '0',
        priority_direction => '0'
    );

    phy : entity work.sim_phy port map (
        clk_i => ck_clk,

        ca_i => phy_ca,
        dq_i => phy_dq_out,
        dq_o => phy_dq_in
    );

    master : entity work.sim_axi_master port map (
        clk_i => axi_clk,
        axi_wa_o => axi_wa,
        axi_wa_ready_i => axi_wa_ready,
        axi_w_o => axi_w,
        axi_w_ready_i => axi_w_ready,
        axi_b_i => axi_b,
        axi_b_ready_o => axi_b_ready,
        axi_ra_o => axi_ra,
        axi_ra_ready_i => axi_ra_ready,
        axi_r_i => axi_r,
        axi_r_ready_o => axi_r_ready
    );
end;
