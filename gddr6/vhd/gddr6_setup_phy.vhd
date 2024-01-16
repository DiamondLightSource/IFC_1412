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

entity gddr6_setup_phy is
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

        -- --------------------------------------------------------------------
        -- CA
        -- Bit 3 in the second tick, ca_i(1)(3), can be overridden by ca3_i.
        -- To allow this set ca_i(1)(3) to '0', then ca3_i(n) will be used.
        ctrl_ca_i : in vector_array(0 to 1)(9 downto 0);
        ctrl_ca3_i : in std_ulogic_vector(0 to 3);
        -- Clock enable, held low during normal operation
        ctrl_cke_n_i : in std_ulogic;

        -- --------------------------------------------------------------------
        -- DQ
        -- Data is transferred in a burst of 128 bytes over two ticks, and so is
        -- organised here as an array of 64 bytes, or 512 bits.
        ctrl_data_i : in std_ulogic_vector(511 downto 0);
        ctrl_data_o : out std_ulogic_vector(511 downto 0);
        ctrl_output_enable_i : in std_ulogic;
        -- Two calculations are presented on the EDC pins here.  edc_in_o is the
        -- value received from the memory, each 8-bit value is the CRC for one
        -- tick of data for 8 lanes.  edc_out_o is the corresponding internally
        -- calculated value, either for incoming data or for outgoing data, as
        -- selected by output_enable_i.
        ctrl_edc_in_o : out vector_array(7 downto 0)(7 downto 0);
        ctrl_edc_out_o : out vector_array(7 downto 0)(7 downto 0);

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

architecture arch of gddr6_setup_phy is
    alias ck_clk : std_ulogic is ck_clk_o;
    signal ck_clk_ok : std_ulogic;
    signal ck_reset : std_ulogic;

    signal setup_ca : vector_array(0 to 1)(9 downto 0);
    signal setup_ca3 : std_ulogic_vector(0 to 3);
    signal setup_cke_n : std_ulogic;
    signal setup_output_enable : std_ulogic;
    signal setup_data_in : std_ulogic_vector(511 downto 0);
    signal setup_data_out : std_ulogic_vector(511 downto 0);
    signal setup_edc_in : vector_array(7 downto 0)(7 downto 0);
    signal setup_edc_out : vector_array(7 downto 0)(7 downto 0);

    signal phy_ca : vector_array(0 to 1)(9 downto 0);
    signal phy_ca3 : std_ulogic_vector(0 to 3);
    signal phy_cke_n : std_ulogic;
    signal phy_output_enable : std_ulogic := '0';
    signal phy_data_in : std_ulogic_vector(511 downto 0);
    signal phy_data_out : std_ulogic_vector(511 downto 0);
    signal phy_dbi_n_in : vector_array(7 downto 0)(7 downto 0);
    signal phy_dbi_n_out : vector_array(7 downto 0)(7 downto 0);
    signal phy_edc_in : vector_array(7 downto 0)(7 downto 0);
    signal phy_edc_out : vector_array(7 downto 0)(7 downto 0);

    signal setup_delay : setup_delay_t;
    signal setup_delay_result : setup_delay_result_t;

    signal phy_setup : phy_setup_t;
    signal phy_status : phy_status_t;

    signal enable_controller : std_ulogic;

begin
    setup : entity work.gddr6_setup port map (
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
        phy_ca3_o => setup_ca3,
        phy_cke_n_o => setup_cke_n,
        phy_output_enable_o => setup_output_enable,
        phy_data_o => setup_data_out,
        phy_data_i => setup_data_in,
        phy_dbi_n_i => phy_dbi_n_in,
        phy_dbi_n_o => phy_dbi_n_out,
        phy_edc_in_i => setup_edc_in,
        phy_edc_out_i => setup_edc_out,

        setup_delay_o => setup_delay,
        setup_delay_i => setup_delay_result,

        phy_setup_o => phy_setup,
        phy_status_i => phy_status,

        enable_controller_o => enable_controller
    );


    phy : entity work.gddr6_phy port map (
        ck_reset_i => ck_reset,
        ck_clk_ok_o => ck_clk_ok,
        ck_clk_o => ck_clk,

        phy_setup_i => phy_setup,
        phy_status_o => phy_status,

        setup_delay_i => setup_delay,
        setup_delay_o => setup_delay_result,

        ca_i => phy_ca,
        ca3_i => phy_ca3,
        cke_n_i => phy_cke_n,

        data_i => phy_data_out,
        data_o => phy_data_in,
        output_enable_i => phy_output_enable,
        dbi_n_i => phy_dbi_n_out,
        dbi_n_o => phy_dbi_n_in,
        edc_in_o => phy_edc_in,
        edc_out_o => phy_edc_out,

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
                phy_ca3 <= ctrl_ca3_i;
                phy_cke_n <= ctrl_cke_n_i;
                phy_data_out <= ctrl_data_i;
                phy_output_enable <= ctrl_output_enable_i;
            else
                phy_ca <= setup_ca;
                phy_ca3 <= setup_ca3;
                phy_cke_n <= setup_cke_n;
                phy_data_out <= setup_data_out;
                phy_output_enable <= setup_output_enable;
            end if;
            ctrl_data_o <= phy_data_in;
            ctrl_edc_in_o <= phy_edc_in;
            ctrl_edc_out_o <= phy_edc_out;
            setup_data_in <= phy_data_in;
            setup_edc_in <= phy_edc_in;
            setup_edc_out <= phy_edc_out;
        end if;
    end process;
end;
