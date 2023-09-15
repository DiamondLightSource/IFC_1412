-- Encapsulation of setup & phy together

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.register_defs.all;
use work.gddr6_register_defines.all;

entity setup_phy is
    generic (
        CK_FREQUENCY : real         -- 250.0 or 300.0 MHz
    );
    port (
        reg_clk_i : in std_ulogic;

        -- Register interface for data access
        write_strobe_i : in std_ulogic_vector(GDDR6_REGS_RANGE);
        write_data_i : in reg_data_array_t(GDDR6_REGS_RANGE);
        write_ack_o : out std_ulogic_vector(GDDR6_REGS_RANGE);
        read_strobe_i : in std_ulogic_vector(GDDR6_REGS_RANGE);
        read_data_o : out reg_data_array_t(GDDR6_REGS_RANGE);
        read_ack_o : out std_ulogic_vector(GDDR6_REGS_RANGE);

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
    signal ck_clk : std_ulogic;
    signal riu_clk : std_ulogic;
    signal ck_clk_ok : std_ulogic;

    signal phy_ca : vector_array(0 to 1)(9 downto 0);
    signal phy_ca3 : std_ulogic_vector(0 to 3);
    signal phy_cke_n : std_ulogic;
    signal phy_dq_t : std_ulogic;
    signal phy_data_in : std_ulogic_vector(511 downto 0);
    signal phy_data_out : std_ulogic_vector(511 downto 0);
    signal phy_edc_in : vector_array(7 downto 0)(7 downto 0);
    signal phy_edc_out : vector_array(7 downto 0)(7 downto 0);

    signal riu_addr : unsigned(9 downto 0);
    signal riu_wr_data : std_ulogic_vector(15 downto 0);
    signal riu_rd_data : std_ulogic_vector(15 downto 0);
    signal riu_wr_en : std_ulogic;
    signal riu_strobe : std_ulogic;
    signal riu_ack : std_ulogic;
    signal riu_error : std_ulogic;
    signal riu_vtc_handshake : std_ulogic;

    signal ck_reset : std_ulogic;
    signal ck_unlock : std_ulogic;
    signal reset_fifo : std_ulogic;
    signal fifo_ok : std_ulogic;
    signal sg_resets_n : std_ulogic_vector(0 to 1);

    signal enable_cabi : std_ulogic;
    signal enable_dbi : std_ulogic;
    signal rx_slip : unsigned_array(0 to 1)(2 downto 0);
    signal tx_slip : unsigned_array(0 to 1)(2 downto 0);

begin
    setup : entity work.gddr6_setup port map (
        ck_clk_i => ck_clk,
        riu_clk_i => riu_clk,
        ck_clk_ok_i => ck_clk_ok,
        reg_clk_i => reg_clk_i,

        write_strobe_i => write_strobe_i,
        write_data_i => write_data_i,
        write_ack_o => write_ack_o,
        read_strobe_i => read_strobe_i,
        read_data_o => read_data_o,
        read_ack_o => read_ack_o,

        phy_ca_o => phy_ca,
        phy_ca3_o => phy_ca3,
        phy_cke_n_o => phy_cke_n,
        phy_dq_t_o => phy_dq_t,
        phy_data_o => phy_data_out,
        phy_data_i => phy_data_in,
        phy_edc_in_i => phy_edc_in,
        phy_edc_out_i => phy_edc_out,

        riu_addr_o => riu_addr,
        riu_wr_data_o => riu_wr_data,
        riu_rd_data_i => riu_rd_data,
        riu_wr_en_o => riu_wr_en,
        riu_strobe_o => riu_strobe,
        riu_ack_i => riu_ack,
        riu_error_i => riu_error,
        riu_vtc_handshake_o => riu_vtc_handshake,

        ck_reset_o => ck_reset,
        ck_unlock_i => ck_unlock,
        reset_fifo_o => reset_fifo,
        fifo_ok_i => fifo_ok,
        sg_resets_n_o => sg_resets_n,

        enable_cabi_o => enable_cabi,
        enable_dbi_o => enable_dbi,
        rx_slip_o => rx_slip,
        tx_slip_o => tx_slip
    );


    phy : entity work.gddr6_phy generic map (
        CK_FREQUENCY => CK_FREQUENCY
    ) port map (
        ck_clk_o => ck_clk,
        riu_clk_o => riu_clk,

        ck_reset_i => ck_reset,
        ck_clk_ok_o => ck_clk_ok,
        ck_unlock_o => ck_unlock,
        reset_fifo_i => reset_fifo,
        fifo_ok_o => fifo_ok,

        sg_resets_n_i => sg_resets_n,

        ca_i => phy_ca,
        ca3_i => phy_ca3,
        cke_n_i => phy_cke_n,
        enable_cabi_i => enable_cabi,

        data_i => phy_data_out,
        data_o => phy_data_in,
        dq_t_i => phy_dq_t,
        enable_dbi_i => enable_dbi,
        edc_in_o => phy_edc_in,
        edc_out_o => phy_edc_out,

        rx_slip_i => rx_slip,
        tx_slip_i => tx_slip,

        riu_addr_i => riu_addr,
        riu_wr_data_i => riu_wr_data,
        riu_rd_data_o => riu_rd_data,
        riu_wr_en_i => riu_wr_en,
        riu_strobe_i => riu_strobe,
        riu_ack_o => riu_ack,
        riu_error_o => riu_error,
        riu_vtc_handshake_i => riu_vtc_handshake,

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
