-- Top level interface to GDDR6 memory controller
--
-- The interface has three components:
--  1. AXI slave interface for memory access
--  2. Simple strobe/ack register interface for configuration
--  3. SG PHY interface for connection to SG memory pins

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_register_defines.all;
use work.register_defs.all;

entity gddr6 is
    generic (
        -- Default SG interface to run at CK=250 MHz, WCK = 1GHz, but support
        -- option to run at 300 MHz/1.2 GHz on speed-grade -2 FPGA
        CK_FREQUENCY : real := 250.0;
        -- In the unlikely case that setup_clk_i is running faster than ck_clk_o
        -- this should be configured so that the correct clock domain crossing
        -- delays are set.  Otherwise leave at the default value.
        REG_FREQUENCY : real := 250.0;
        -- Similarly, if the AXI clock is running fast this should be set
        AXI_FREQUENCY : real := 250.0
    );
    port  (
        -- Register Setup Interface
        setup_clk_i : in std_ulogic;

        write_strobe_i : in std_ulogic_vector(GDDR6_REGS_RANGE);
        write_data_i : in reg_data_array_t(GDDR6_REGS_RANGE);
        write_ack_o : out std_ulogic_vector(GDDR6_REGS_RANGE);
        read_strobe_i : in std_ulogic_vector(GDDR6_REGS_RANGE);
        read_data_o : out reg_data_array_t(GDDR6_REGS_RANGE);
        read_ack_o : out std_ulogic_vector(GDDR6_REGS_RANGE);

        -- Asynchronous trigger to capture SG activity
        setup_trigger_i : in std_ulogic;


        -- AXI slave interface to 4GB GDDR6 SGRAM
        axi_clk_i : in std_ulogic;

        axi_request_i : in axi_request_t;
        axi_response_o : out axi_response_t;
        axi_stats_o : out axi_stats_t;


        -- GDDR6 PHY Interface
        pad_SG1_RESET_N_o : out std_logic;
        pad_SG2_RESET_N_o : out std_logic;
        pad_SG12_CKE_N_o : out std_logic;
        pad_SG12_CK_P_i : in std_logic;
        pad_SG12_CK_N_i : in std_logic;

        pad_SG12_CABI_N_o : out std_logic;
        pad_SG12_CAL_o : out std_logic_vector(2 downto 0);
        pad_SG1_CA3_A_o : out std_logic;
        pad_SG1_CA3_B_o : out std_logic;
        pad_SG2_CA3_A_o : out std_logic;
        pad_SG2_CA3_B_o : out std_logic;
        pad_SG12_CAU_o : out std_logic_vector(9 downto 4);

        pad_SG1_WCK_P_i : in std_logic;
        pad_SG1_WCK_N_i : in std_logic;

        pad_SG1_DQ_A_io : inout std_logic_vector(15 downto 0);
        pad_SG1_DBI_N_A_io : inout std_logic_vector(1 downto 0);
        pad_SG1_EDC_A_io : inout std_logic_vector(1 downto 0);
        pad_SG1_DQ_B_io : inout std_logic_vector(15 downto 0);
        pad_SG1_DBI_N_B_io : inout std_logic_vector(1 downto 0);
        pad_SG1_EDC_B_io : inout std_logic_vector(1 downto 0);

        pad_SG2_WCK_P_i : in std_logic;
        pad_SG2_WCK_N_i : in std_logic;

        pad_SG2_DQ_A_io : inout std_logic_vector(15 downto 0);
        pad_SG2_DBI_N_A_io : inout std_logic_vector(1 downto 0);
        pad_SG2_EDC_A_io : inout std_logic_vector(1 downto 0);
        pad_SG2_DQ_B_io : inout std_logic_vector(15 downto 0);
        pad_SG2_DBI_N_B_io : inout std_logic_vector(1 downto 0);
        pad_SG2_EDC_B_io : inout std_logic_vector(1 downto 0)
    );
end;

architecture arch of gddr6 is
    signal ck_clk : std_ulogic;

    signal ctrl_read_request : axi_ctrl_read_request_t;
    signal ctrl_read_response : axi_ctrl_read_response_t;
    signal ctrl_write_request : axi_ctrl_write_request_t;
    signal ctrl_write_response : axi_ctrl_write_response_t;

    signal ctrl_setup : ctrl_setup_t;
    signal temperature : sg_temperature_t;

    signal ca : phy_ca_t;
    signal dq_out : phy_dq_out_t;
    signal dq_in : phy_dq_in_t;

begin
    axi : entity work.gddr6_axi generic map (
        AXI_FREQUENCY => AXI_FREQUENCY,
        CK_FREQUENCY => CK_FREQUENCY
    ) port map (
        axi_clk_i => axi_clk_i,
        axi_request_i => axi_request_i,
        axi_response_o => axi_response_o,
        axi_stats_o => axi_stats_o,

        ck_clk_i => ck_clk,
        ctrl_read_request_o => ctrl_read_request,
        ctrl_read_response_i => ctrl_read_response,
        ctrl_write_request_o => ctrl_write_request,
        ctrl_write_response_i => ctrl_write_response
    );


    ctrl : entity work.gddr6_ctrl port map (
        clk_i => ck_clk,

        ctrl_setup_i => ctrl_setup,
        temperature_o => temperature,

        axi_read_request_i => ctrl_read_request,
        axi_read_response_o => ctrl_read_response,
        axi_write_request_i => ctrl_write_request,
        axi_write_response_o => ctrl_write_response,

        phy_ca_o => ca,
        phy_dq_o => dq_out,
        phy_dq_i => dq_in
    );


    setup_phy : entity work.gddr6_setup_phy generic map (
        CK_FREQUENCY => CK_FREQUENCY,
        REG_FREQUENCY => REG_FREQUENCY
    ) port map (
        reg_clk_i => setup_clk_i,
        ck_clk_o => ck_clk,

        write_strobe_i => write_strobe_i,
        write_data_i => write_data_i,
        write_ack_o => write_ack_o,
        read_strobe_i => read_strobe_i,
        read_data_o => read_data_o,
        read_ack_o => read_ack_o,

        setup_trigger_i => setup_trigger_i,

        ctrl_setup_o => ctrl_setup,
        ctrl_ca_i => ca,
        ctrl_dq_i => dq_out,
        ctrl_dq_o => dq_in,
        temperature_i => temperature,

        pad_SG12_CK_P_i => pad_SG12_CK_P_i,
        pad_SG12_CK_N_i => pad_SG12_CK_N_i,
        pad_SG1_WCK_P_i => pad_SG1_WCK_P_i,
        pad_SG1_WCK_N_i => pad_SG1_WCK_N_i,
        pad_SG2_WCK_P_i => pad_SG2_WCK_P_i,
        pad_SG2_WCK_N_i => pad_SG2_WCK_N_i,
        pad_SG1_RESET_N_o => pad_SG1_RESET_N_o,
        pad_SG2_RESET_N_o => pad_SG2_RESET_N_o,
        pad_SG12_CKE_N_o => pad_SG12_CKE_N_o,
        pad_SG12_CABI_N_o => pad_SG12_CABI_N_o,
        pad_SG12_CAL_o => pad_SG12_CAL_o,
        pad_SG1_CA3_A_o => pad_SG1_CA3_A_o,
        pad_SG1_CA3_B_o => pad_SG1_CA3_B_o,
        pad_SG2_CA3_A_o => pad_SG2_CA3_A_o,
        pad_SG2_CA3_B_o => pad_SG2_CA3_B_o,
        pad_SG12_CAU_o => pad_SG12_CAU_o,
        pad_SG1_DQ_A_io => pad_SG1_DQ_A_io,
        pad_SG1_DQ_B_io => pad_SG1_DQ_B_io,
        pad_SG2_DQ_A_io => pad_SG2_DQ_A_io,
        pad_SG2_DQ_B_io => pad_SG2_DQ_B_io,
        pad_SG1_DBI_N_A_io => pad_SG1_DBI_N_A_io,
        pad_SG1_DBI_N_B_io => pad_SG1_DBI_N_B_io,
        pad_SG2_DBI_N_A_io => pad_SG2_DBI_N_A_io,
        pad_SG2_DBI_N_B_io => pad_SG2_DBI_N_B_io,
        pad_SG1_EDC_A_io => pad_SG1_EDC_A_io,
        pad_SG1_EDC_B_io => pad_SG1_EDC_B_io,
        pad_SG2_EDC_A_io => pad_SG2_EDC_A_io,
        pad_SG2_EDC_B_io => pad_SG2_EDC_B_io
    );
end;
