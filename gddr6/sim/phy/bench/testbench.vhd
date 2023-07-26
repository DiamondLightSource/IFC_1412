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
    -- Base frequency in MHz, either 250 or 300 MHz
    constant CK_FREQUENCY : real := 300.0;

    constant CK_PERIOD : time := 1 us / CK_FREQUENCY;
    constant WCK_PERIOD : time := CK_PERIOD / 4;

    procedure write(message : string) is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

    signal ck_clk_out : std_ulogic;
    signal riu_clk : std_ulogic;
    signal ck_reset_in : std_ulogic;
    signal ck_ok_out : std_ulogic;
    signal ck_unlock_out : std_ulogic;
    signal fifo_ok_out : std_ulogic;
    signal sg_resets_in : std_ulogic_vector(0 to 1);
    signal enable_cabi_in : std_ulogic;
    signal enable_dbi_in : std_ulogic;

    signal ca_in : vector_array(0 to 1)(9 downto 0);
    signal ca3_in : std_ulogic_vector(0 to 3);
    signal cke_n_in : std_ulogic;
    signal edc_in_out : vector_array(7 downto 0)(7 downto 0);
    signal edc_out_out : vector_array(7 downto 0)(7 downto 0);

    signal data_in : std_ulogic_vector(511 downto 0);
    signal data_out : std_ulogic_vector(511 downto 0);
    signal edc_out : std_ulogic_vector(63 downto 0);
    signal dq_t_in : std_ulogic;

    signal riu_addr_in : unsigned(9 downto 0);
    signal riu_wr_data_in : std_ulogic_vector(15 downto 0);
    signal riu_rd_data_out : std_ulogic_vector(15 downto 0);
    signal riu_wr_en_in : std_ulogic;
    signal riu_strobe_in : std_ulogic;
    signal riu_ack_out : std_ulogic;

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

    signal ck_valid : std_ulogic;

begin
    phy : entity work.gddr6_phy generic map (
        CK_FREQUENCY => CK_FREQUENCY
    ) port map (
        ck_clk_o => ck_clk_out,
        riu_clk_o => riu_clk,

        ck_reset_i => ck_reset_in,
        ck_ok_o => ck_ok_out,
        ck_unlock_o => ck_unlock_out,
        fifo_ok_o => fifo_ok_out,
        sg_resets_i => sg_resets_in,

        enable_cabi_i => enable_cabi_in,
        ca_i => ca_in,
        ca3_i => ca3_in,
        cke_n_i => cke_n_in,

        data_i => data_in,
        data_o => data_out,
        dq_t_i => dq_t_in,
        enable_dbi_i => enable_dbi_in,
        edc_in_o => edc_in_out,
        edc_out_o => edc_out_out,

        riu_addr_i => riu_addr_in,
        riu_wr_data_i => riu_wr_data_in,
        riu_rd_data_o => riu_rd_data_out,
        riu_wr_en_i => riu_wr_en_in,
        riu_strobe_i => riu_strobe_in,
        riu_ack_o => riu_ack_out,

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

    data_in <= (others => '0');
    dq_t_in <= '0';

    pad_SG12_CK_P <= not pad_SG12_CK_P after CK_PERIOD / 2 when ck_valid;
    pad_SG12_CK_N <= not pad_SG12_CK_P;

    pad_SG1_WCK_P <= not pad_SG1_WCK_P after WCK_PERIOD / 2 when ck_ok_out;
    pad_SG1_WCK_N <= not pad_SG1_WCK_P;
    pad_SG2_WCK_P <= not pad_SG1_WCK_P after WCK_PERIOD / 2 when ck_ok_out;
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

    process
        procedure riu_wait is
        begin
            wait until rising_edge(riu_clk);
        end;

        procedure riu_access(
            address : natural; write : std_ulogic := '0';
            data : std_ulogic_vector(15 downto 0) := X"0000") is
        begin
            riu_wait;
            riu_addr_in <= to_unsigned(address, 10);
            riu_wr_data_in <= data;
            riu_wr_en_in <= write;
            riu_strobe_in <= '1';

            riu_wait;
            riu_strobe_in <= '0';

            while not riu_ack_out loop
                riu_wait;
            end loop;
        end;

    begin
        riu_strobe_in <= '0';

        ck_valid <= '1';
        ck_reset_in <= '1';
        wait for 50 ns;
        ck_reset_in <= '0';

        wait until ck_ok_out;

        for a in 0 to 63 loop
            riu_access(a);
        end loop;

        wait;
    end process;
end;
