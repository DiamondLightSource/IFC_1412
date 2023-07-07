library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use std.textio.all;

use work.support.all;

entity testbench is
end testbench;


architecture arch of testbench is

    procedure write(message : string) is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

    signal ck_clk_out : std_ulogic;
    signal ck_reset_in : std_ulogic;
    signal ck_ok_out : std_ulogic;
    signal fifo_ok_out : std_ulogic;
    signal sg_resets_in : std_ulogic_vector(0 to 1);
    signal enable_cabi_in : std_ulogic;
    signal enable_dbi_in : std_ulogic;

    signal ca_in : vector_array(0 to 1)(9 downto 0);
    signal ca3_in : std_ulogic_vector(0 to 3);
    signal cke_n_in : std_ulogic;
    signal edc_in : std_ulogic_vector(7 downto 0);
    signal edc_t_in : std_ulogic;

    signal data_in : std_ulogic_vector(511 downto 0);
    signal data_out : std_ulogic_vector(511 downto 0);
    signal edc_out : std_ulogic_vector(63 downto 0);
    signal dq_t_in : std_ulogic;

    signal delay_select_in : unsigned(6 downto 0);
    signal delay_rx_tx_n_in : std_ulogic;
    signal delay_write_in : std_ulogic;
    signal delay_in : unsigned(8 downto 0);
    signal delay_strobe_in : std_ulogic;
    signal delay_ack_out : std_ulogic;
    signal delay_out : unsigned(8 downto 0);

    signal pad_SG12_CK_P : std_ulogic := '0';
    signal pad_SG12_CK_N : std_ulogic;
    signal pad_SG1_WCK_P : std_ulogic := '0';
    signal pad_SG1_WCK_N : std_ulogic;
    signal pad_SG2_WCK_P : std_ulogic := '0';
    signal pad_SG2_WCK_N : std_ulogic;
    signal pad_SG1_RESET_N : std_ulogic;
    signal pad_SG2_RESET_N : std_ulogic;
    signal pad_SG12_CKE_N : std_ulogic;
    signal pad_SG12_CABI_N : std_ulogic;
    signal pad_SG12_CAL : std_ulogic_vector(2 downto 0);
    signal pad_SG1_CA3_A : std_ulogic;
    signal pad_SG1_CA3_B : std_ulogic;
    signal pad_SG2_CA3_A : std_ulogic;
    signal pad_SG2_CA3_B : std_ulogic;
    signal pad_SG12_CAU : std_ulogic_vector(9 downto 4);
    signal pad_SG1_DQ_A : std_logic_vector(15 downto 0);
    signal pad_SG1_DQ_B : std_logic_vector(15 downto 0);
    signal pad_SG2_DQ_A : std_logic_vector(15 downto 0);
    signal pad_SG2_DQ_B : std_logic_vector(15 downto 0);
    signal pad_SG1_DBI_N_A : std_logic_vector(1 downto 0);
    signal pad_SG1_DBI_N_B : std_logic_vector(1 downto 0);
    signal pad_SG2_DBI_N_A : std_logic_vector(1 downto 0);
    signal pad_SG2_DBI_N_B : std_logic_vector(1 downto 0);
    signal pad_SG1_EDC_A : std_logic_vector(1 downto 0);
    signal pad_SG1_EDC_B : std_logic_vector(1 downto 0);
    signal pad_SG2_EDC_A : std_logic_vector(1 downto 0);
    signal pad_SG2_EDC_B : std_logic_vector(1 downto 0);

begin
    phy : entity work.gddr6_phy port map (
        ck_clk_o => ck_clk_out,
        ck_reset_i => ck_reset_in,
        ck_ok_o => ck_ok_out,
        fifo_ok_o => fifo_ok_out,
        sg_resets_i => sg_resets_in,

        enable_cabi_i => enable_cabi_in,
        ca_i => ca_in,
        ca3_i => ca3_in,
        cke_n_i => cke_n_in,
        edc_i => edc_in,
        edc_t_i => edc_t_in,

        enable_dbi_i => enable_dbi_in,
        data_i => data_in,
        data_o => data_out,
        edc_o => edc_out,
        dq_t_i => dq_t_in,

        delay_select_i => delay_select_in,
        delay_rx_tx_n_i => delay_rx_tx_n_in,
        delay_write_i => delay_write_in,
        delay_i => delay_in,
        delay_strobe_i => delay_strobe_in,
        delay_ack_o => delay_ack_out,
        delay_o => delay_out,

        pad_SG12_CK_P_i => pad_SG12_CK_P,
        pad_SG12_CK_N_i => pad_SG12_CK_N,
        pad_SG1_WCK_P_i => pad_SG1_WCK_P,
        pad_SG1_WCK_N_i => pad_SG1_WCK_N,
        pad_SG2_WCK_P_i => pad_SG2_WCK_P,
        pad_SG2_WCK_N_i => pad_SG2_WCK_N,
        pad_SG1_RESET_N_o => pad_SG1_RESET_N,
        pad_SG2_RESET_N_o => pad_SG2_RESET_N,
        pad_SG12_CKE_N_o => pad_SG12_CKE_N,
        pad_SG12_CABI_N_o => pad_SG12_CABI_N,
        pad_SG12_CAL_o => pad_SG12_CAL,
        pad_SG1_CA3_A_o => pad_SG1_CA3_A,
        pad_SG1_CA3_B_o => pad_SG1_CA3_B,
        pad_SG2_CA3_A_o => pad_SG2_CA3_A,
        pad_SG2_CA3_B_o => pad_SG2_CA3_B,
        pad_SG12_CAU_o => pad_SG12_CAU,
        pad_SG1_DQ_A_io => pad_SG1_DQ_A,
        pad_SG1_DQ_B_io => pad_SG1_DQ_B,
        pad_SG2_DQ_A_io => pad_SG2_DQ_A,
        pad_SG2_DQ_B_io => pad_SG2_DQ_B,
        pad_SG1_DBI_N_A_io => pad_SG1_DBI_N_A,
        pad_SG1_DBI_N_B_io => pad_SG1_DBI_N_B,
        pad_SG2_DBI_N_A_io => pad_SG2_DBI_N_A,
        pad_SG2_DBI_N_B_io => pad_SG2_DBI_N_B,
        pad_SG1_EDC_A_io => pad_SG1_EDC_A,
        pad_SG1_EDC_B_io => pad_SG1_EDC_B,
        pad_SG2_EDC_A_io => pad_SG2_EDC_A,
        pad_SG2_EDC_B_io => pad_SG2_EDC_B
    );

    sg_resets_in <= "11";
    enable_cabi_in <= '0';
    enable_dbi_in <= '0';

    ca_in <= (others => (others => '0'));
    ca3_in <= (others => '0');
    cke_n_in <= '0';
    edc_in <= (others => '1');
    edc_t_in <= '0';

    data_in <= (others => '0');
    dq_t_in <= '0';

    delay_select_in <= (others => '0');
    delay_rx_tx_n_in <= '0';
    delay_write_in <= '0';
    delay_in <= (others => '0');
    delay_strobe_in <= '0';

    pad_SG12_CK_P <= not pad_SG12_CK_P after 2 ns;
    pad_SG12_CK_N <= not pad_SG12_CK_P;

    pad_SG1_WCK_P <= not pad_SG1_WCK_P after 0.5 ns when ck_ok_out;
    pad_SG1_WCK_N <= not pad_SG1_WCK_P;
    pad_SG2_WCK_P <= not pad_SG1_WCK_P after 0.5 ns when ck_ok_out;
    pad_SG2_WCK_N <= not pad_SG2_WCK_P;

    pad_SG1_DQ_A <= (others => 'Z');
    pad_SG1_DQ_B <= (others => 'Z');
    pad_SG2_DQ_A <= (others => 'Z');
    pad_SG2_DQ_B <= (others => 'Z');
    pad_SG1_DBI_N_A <= (others => 'Z');
    pad_SG1_DBI_N_B <= (others => 'Z');
    pad_SG2_DBI_N_A <= (others => 'Z');
    pad_SG2_DBI_N_B <= (others => 'Z');
    pad_SG1_EDC_A <= (others => 'Z');
    pad_SG1_EDC_B <= (others => 'Z');
    pad_SG2_EDC_A <= (others => 'Z');
    pad_SG2_EDC_B <= (others => 'Z');

    process begin
        ck_reset_in <= '1';
        wait for 50 ns;
        ck_reset_in <= '0';
        wait;
    end process;
end;
