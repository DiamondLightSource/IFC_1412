-- Top level control for gddr6 setup

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.gddr6_register_defines.all;
use work.gddr6_defs.all;

entity gddr6_setup is
    generic (
        -- Must be set to the minimum clock period of the register and CK clocks
        MAX_DELAY : real := 4.0
    );
    port (
        reg_clk_i : in std_ulogic;      -- Register clock

        -- Register interface for data access on reg_clk_i
        write_strobe_i : in std_ulogic_vector(GDDR6_REGS_RANGE);
        write_data_i : in reg_data_array_t(GDDR6_REGS_RANGE);
        write_ack_o : out std_ulogic_vector(GDDR6_REGS_RANGE);
        read_strobe_i : in std_ulogic_vector(GDDR6_REGS_RANGE);
        read_data_o : out reg_data_array_t(GDDR6_REGS_RANGE);
        read_ack_o : out std_ulogic_vector(GDDR6_REGS_RANGE);

        setup_trigger_i : in std_ulogic;

        -- CK clock, used for all other elements of the interface
        ck_reset_o : out std_ulogic;    -- Reset control for CK
        ck_clk_i : in std_ulogic;       -- CK clock
        ck_clk_ok_i : in std_ulogic;    -- Qualifies status of CK clock

        -- PHY interface on ck_clk_i, connected to gddr6_phy
        phy_ca_o : out phy_ca_t;
        phy_ca_i : in phy_ca_t;
        phy_output_enable_i : in std_ulogic;
        phy_dq_o : out phy_dq_out_t;
        phy_dq_i : in phy_dq_in_t;
        phy_dbi_n_o : out phy_dbi_t;
        phy_dbi_n_i : in phy_dbi_t;

        -- PHY configuration and status
        phy_setup_o : out phy_setup_t;
        phy_status_i : in phy_status_t;

        -- Delay control
        setup_delay_o : out setup_delay_t;
        setup_delay_i : in setup_delay_result_t;

        -- Controller enable
        ctrl_setup_o : out ctrl_setup_t;
        enable_controller_o : out std_ulogic
    );
end;

architecture arch of gddr6_setup is
    signal ck_clk_ok : std_ulogic;
    signal capture_edc_out : std_ulogic;
    signal reg_enable_controller : std_ulogic;

begin
    sync_ck_ok : entity work.sync_bit port map (
        clk_i => reg_clk_i,
        bit_i => ck_clk_ok_i,
        bit_o => ck_clk_ok
    );


    control : entity work.gddr6_setup_control generic map (
        MAX_DELAY => MAX_DELAY
    ) port map (
        reg_clk_i => reg_clk_i,
        ck_clk_i => ck_clk_i,
        ck_clk_ok_i => ck_clk_ok,
        ck_reset_o => ck_reset_o,

        write_strobe_i => write_strobe_i(GDDR6_CONTROL_REGS),
        write_data_i => write_data_i(GDDR6_CONTROL_REGS),
        write_ack_o => write_ack_o(GDDR6_CONTROL_REGS),
        read_strobe_i => read_strobe_i(GDDR6_CONTROL_REGS),
        read_data_o => read_data_o(GDDR6_CONTROL_REGS),
        read_ack_o => read_ack_o(GDDR6_CONTROL_REGS),

        phy_setup_o => phy_setup_o,
        phy_status_i => phy_status_i,

        capture_edc_out_o => capture_edc_out,
        ctrl_setup_o => ctrl_setup_o,
        ck_enable_controller_o => enable_controller_o,
        reg_enable_controller_o => reg_enable_controller
    );


    delay : entity work.gddr6_setup_delay generic map (
        MAX_DELAY => MAX_DELAY
    ) port map (
        reg_clk_i => reg_clk_i,
        ck_clk_i => ck_clk_i,
        ck_clk_ok_i => ck_clk_ok,

        write_strobe_i => write_strobe_i(GDDR6_DELAY_REG),
        write_data_i => write_data_i(GDDR6_DELAY_REG),
        write_ack_o => write_ack_o(GDDR6_DELAY_REG),
        read_strobe_i => read_strobe_i(GDDR6_DELAY_REG),
        read_data_o => read_data_o(GDDR6_DELAY_REG),
        read_ack_o => read_ack_o(GDDR6_DELAY_REG),

        setup_delay_o => setup_delay_o,
        setup_delay_i => setup_delay_i
    );


    exchange : entity work.gddr6_setup_exchange generic map (
        MAX_DELAY => MAX_DELAY
    ) port map (
        reg_clk_i => reg_clk_i,
        ck_clk_i => ck_clk_i,
        ck_clk_ok_i => ck_clk_ok,

        write_strobe_i => write_strobe_i(GDDR6_EXCHANGE_REGS),
        write_data_i => write_data_i(GDDR6_EXCHANGE_REGS),
        write_ack_o => write_ack_o(GDDR6_EXCHANGE_REGS),
        read_strobe_i => read_strobe_i(GDDR6_EXCHANGE_REGS),
        read_data_o => read_data_o(GDDR6_EXCHANGE_REGS),
        read_ack_o => read_ack_o(GDDR6_EXCHANGE_REGS),

        enable_controller_i => reg_enable_controller,
        setup_trigger_i => setup_trigger_i,
        capture_edc_out_i => capture_edc_out,

        phy_ca_o => phy_ca_o,
        phy_ca_i => phy_ca_i,
        phy_output_enable_i => phy_output_enable_i,
        phy_dq_o => phy_dq_o,
        phy_dq_i => phy_dq_i,
        phy_dbi_n_o => phy_dbi_n_o,
        phy_dbi_n_i => phy_dbi_n_i
    );
end;
