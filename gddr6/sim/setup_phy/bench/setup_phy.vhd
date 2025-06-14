-- Encapsulation of setup & phy together
--
-- During configuration the CA and DQ interface is controlled through the setup
-- register interface.  After setup is complete this interface is directly
-- connected to the memory controller.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.register_defs.all;
use work.gddr6_register_defines.all;
use work.gddr6_defs.all;

entity setup_phy is
    generic (
        -- Default SG interface to run at CK=250 MHz, WCK = 1GHz, but support
        -- option to run at 300 MHz/1.2 GHz on speed-grade -2 FPGA
        CK_FREQUENCY : real := 250.0;
        -- In the unlikely case that reg_clk_i is running faster than ck_clk_o
        -- this should be configured so that the correct clock domain crossing
        -- delays are set.  Otherwise leave at the default value.
        REG_FREQUENCY : real := 250.0
    );
    port (
        reg_clk_i : in std_ulogic;      -- Register interface only
        ck_clk_o : out std_ulogic;      -- Memory controller only

        -- --------------------------------------------------------------------
        -- Register interface for initial setup on reg_clk_i
        write_strobe_i : in std_ulogic_vector(GDDR6_REGS_RANGE);
        write_data_i : in reg_data_array_t(GDDR6_REGS_RANGE);
        write_ack_o : out std_ulogic_vector(GDDR6_REGS_RANGE);
        read_strobe_i : in std_ulogic_vector(GDDR6_REGS_RANGE);
        read_data_o : out reg_data_array_t(GDDR6_REGS_RANGE);
        read_ack_o : out std_ulogic_vector(GDDR6_REGS_RANGE);

        setup_trigger_i : in std_ulogic;

        -- --------------------------------------------------------------------
        -- CTRL
        ctrl_setup_o : out ctrl_setup_t;
        ctrl_ca_i : in phy_ca_t;
        ctrl_dq_i : in phy_dq_out_t;
        ctrl_dq_o : out phy_dq_in_t;
        temperature_i : in sg_temperature_t;

        -- --------------------------------------------------------------------
        -- GDDR pins
        pad_SG12_CK_P_i : in std_ulogic;
        pad_SG12_CK_N_i : in std_ulogic;
        pad_SG1_WCK_P_i : in std_ulogic;
        pad_SG1_WCK_N_i : in std_ulogic;
        pad_SG2_WCK_P_i : in std_ulogic;
        pad_SG2_WCK_N_i : in std_ulogic;
        pad_SG1_RESET_N_o : out std_ulogic;
        pad_SG2_RESET_N_o : out std_ulogic;
        pad_SG12_CKE_N_o : out std_ulogic;
        pad_SG12_CABI_N_o : out std_ulogic;
        pad_SG12_CAL_o : out std_ulogic_vector(2 downto 0);
        pad_SG1_CA3_A_o : out std_ulogic;
        pad_SG1_CA3_B_o : out std_ulogic;
        pad_SG2_CA3_A_o : out std_ulogic;
        pad_SG2_CA3_B_o : out std_ulogic;
        pad_SG12_CAU_o : out std_ulogic_vector(9 downto 4);
        pad_SG1_DQ_A_io : inout std_logic_vector(15 downto 0);
        pad_SG1_DQ_B_io : inout std_logic_vector(15 downto 0);
        pad_SG2_DQ_A_io : inout std_logic_vector(15 downto 0);
        pad_SG2_DQ_B_io : inout std_logic_vector(15 downto 0);
        pad_SG1_DBI_N_A_io : inout std_logic_vector(1 downto 0);
        pad_SG1_DBI_N_B_io : inout std_logic_vector(1 downto 0);
        pad_SG2_DBI_N_A_io : inout std_logic_vector(1 downto 0);
        pad_SG2_DBI_N_B_io : inout std_logic_vector(1 downto 0);
        pad_SG1_EDC_A_io : inout std_logic_vector(1 downto 0);
        pad_SG1_EDC_B_io : inout std_logic_vector(1 downto 0);
        pad_SG2_EDC_A_io : inout std_logic_vector(1 downto 0);
        pad_SG2_EDC_B_io : inout std_logic_vector(1 downto 0)
    );
end;

architecture arch of setup_phy is
    -- For clock domain crossing in gddr6_setup we need to allow for the fastest
    -- clock.
    constant MAX_DELAY : real := 1000.0 / maximum(CK_FREQUENCY, REG_FREQUENCY);

    alias ck_clk : std_ulogic is ck_clk_o;
    signal ck_clk_ok : std_ulogic;
    signal ck_reset : std_ulogic;

    signal setup_ca : phy_ca_t;
    signal setup_dq_out : phy_dq_out_t;
    signal setup_dq_in : phy_dq_in_t;
    signal setup_dbi_n_in : vector_array(7 downto 0)(7 downto 0);
    signal setup_dbi_n_out : vector_array(7 downto 0)(7 downto 0);

    signal phy_ca : phy_ca_t;
    signal phy_dq_out : phy_dq_out_t;
    signal phy_dq_in : phy_dq_in_t;
    signal phy_dbi_n_in : vector_array(7 downto 0)(7 downto 0);
    signal phy_dbi_n_out : vector_array(7 downto 0)(7 downto 0);

    signal setup_delay : setup_delay_t;
    signal setup_delay_result : setup_delay_result_t;

    signal phy_setup : phy_setup_t;
    signal phy_status : phy_status_t;

    signal enable_controller : std_ulogic;

begin
    setup : entity work.gddr6_setup generic map (
        MAX_DELAY => MAX_DELAY
    ) port map (
        reg_clk_i => reg_clk_i,

        write_strobe_i => write_strobe_i,
        write_data_i => write_data_i,
        write_ack_o => write_ack_o,
        read_strobe_i => read_strobe_i,
        read_data_o => read_data_o,
        read_ack_o => read_ack_o,

        ck_clk_i => ck_clk,
        ck_clk_ok_i => ck_clk_ok,
        ck_reset_o => ck_reset,

        phy_ca_o => setup_ca,
        phy_ca_i => phy_ca,
        phy_output_enable_i => phy_dq_out.output_enable,
        phy_dq_o => setup_dq_out,
        phy_dq_i => setup_dq_in,
        phy_dbi_n_i => setup_dbi_n_in,
        phy_dbi_n_o => setup_dbi_n_out,

        setup_delay_o => setup_delay,
        setup_delay_i => setup_delay_result,

        phy_setup_o => phy_setup,
        phy_status_i => phy_status,

        setup_trigger_i => setup_trigger_i,
        ctrl_setup_o => ctrl_setup_o,
        enable_controller_o => enable_controller,
        temperature_i => temperature_i
    );


    phy : entity work.gddr6_phy generic map (
        CK_FREQUENCY => CK_FREQUENCY
    ) port map (
        ck_reset_i => ck_reset,
        ck_clk_ok_o => ck_clk_ok,
        ck_clk_o => ck_clk,

        phy_setup_i => phy_setup,
        phy_status_o => phy_status,

        setup_delay_i => setup_delay,
        setup_delay_o => setup_delay_result,

        ca_i => phy_ca,
        dq_i => phy_dq_out,
        dq_o => phy_dq_in,
        dbi_n_i => phy_dbi_n_out,
        dbi_n_o => phy_dbi_n_in,

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


    -- Setup and controller MUX.  Not registered at present, but this can be
    -- done if required.
    process (ck_clk) begin
        if rising_edge(ck_clk) then
            if enable_controller then
                phy_ca <= ctrl_ca_i;
                phy_dq_out <= ctrl_dq_i;
            else
                phy_ca <= setup_ca;
                phy_dq_out <= setup_dq_out;
            end if;
            ctrl_dq_o <= phy_dq_in;
            setup_dq_in <= phy_dq_in;
            -- These two signals are only used during training, but ensure that
            -- DBI and DQ data are aligned
            phy_dbi_n_out <= setup_dbi_n_out;
            setup_dbi_n_in <= phy_dbi_n_in;
        end if;
    end process;
end;
