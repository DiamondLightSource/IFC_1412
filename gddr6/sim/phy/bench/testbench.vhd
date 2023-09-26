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

    signal ck_clk : std_ulogic;
    signal ck_reset_in : std_ulogic;
    signal ck_ok_out : std_ulogic;
    signal ck_unlock_out : std_ulogic;
    signal reset_fifo_in : std_ulogic_vector(0 to 1);
    signal fifo_ok_out : std_ulogic_vector(0 to 1);
    signal sg_resets_n_in : std_ulogic_vector(0 to 1);
    signal enable_cabi_in : std_ulogic;
    signal enable_dbi_in : std_ulogic;

    signal ca_in : vector_array(0 to 1)(9 downto 0)
        := (others => (others => '0'));
    signal ca3_in : std_ulogic_vector(0 to 3);
    signal cke_n_in : std_ulogic;
    signal edc_in_out : vector_array(7 downto 0)(7 downto 0);
    signal edc_out_out : vector_array(7 downto 0)(7 downto 0);

    signal data_in : std_ulogic_vector(511 downto 0) := (others => '0');
    signal data_out : std_ulogic_vector(511 downto 0);
    signal edc_out : std_ulogic_vector(63 downto 0);
    signal dq_t_in : std_ulogic;

    signal delay_address_in : unsigned(7 downto 0);
    signal delay_in : unsigned(7 downto 0);
    signal delay_up_down_n_in : std_ulogic;
    signal delay_strobe_in : std_ulogic;
    signal delay_ack_out : std_ulogic;
    signal delay_reset_ca_in : std_ulogic;
    signal delay_reset_dq_rx_in : std_ulogic;
    signal delay_reset_dq_tx_in : std_ulogic;

    signal delay_dq_rx_out : vector_array(63 downto 0)(8 downto 0);
    signal delay_dq_tx_out : vector_array(63 downto 0)(8 downto 0);
    signal delay_dbi_rx_out : vector_array(7 downto 0)(8 downto 0);
    signal delay_dbi_tx_out : vector_array(7 downto 0)(8 downto 0);
    signal delay_edc_rx_out : vector_array(7 downto 0)(8 downto 0);

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
        ck_reset_i => ck_reset_in,
        ck_clk_ok_o => ck_ok_out,
        ck_clk_o => ck_clk,

        ck_unlock_o => ck_unlock_out,
        reset_fifo_i => reset_fifo_in,
        fifo_ok_o => fifo_ok_out,
        sg_resets_n_i => sg_resets_n_in,
        enable_cabi_i => enable_cabi_in,
        enable_dbi_i => enable_dbi_in,

        ca_i => ca_in,
        ca3_i => ca3_in,
        cke_n_i => cke_n_in,

        data_i => data_in,
        data_o => data_out,
        dq_t_i => dq_t_in,
        edc_in_o => edc_in_out,
        edc_out_o => edc_out_out,

        delay_address_i => delay_address_in,
        delay_i => delay_in,
        delay_up_down_n_i => delay_up_down_n_in,
        delay_strobe_i => delay_strobe_in,
        delay_ack_o => delay_ack_out,
        delay_reset_ca_i => delay_reset_ca_in,
        delay_reset_dq_rx_i => delay_reset_dq_rx_in,
        delay_reset_dq_tx_i => delay_reset_dq_tx_in,

        delay_dq_rx_o => delay_dq_rx_out,
        delay_dq_tx_o => delay_dq_tx_out,
        delay_dbi_rx_o => delay_dbi_rx_out,
        delay_dbi_tx_o => delay_dbi_tx_out,
        delay_edc_rx_o => delay_edc_rx_out,

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

    sg_resets_n_in <= "11";
    enable_cabi_in <= '0';
    enable_dbi_in <= '0';

    ca3_in <= (others => '0');
    cke_n_in <= '1';

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
    pad_SG1_EDC_A <= (others => 'H');
    pad_SG1_EDC_B <= (others => 'H');
    pad_SG2_EDC_A <= (others => 'H');
    pad_SG2_EDC_B <= (others => 'H');

    process
        procedure clk_wait(count : natural := 1) is
        begin
            for n in 1 to count loop
                wait until rising_edge(ck_clk);
            end loop;
        end;

        procedure write_delay(
            address : natural; delay : natural; up_down_n : std_ulogic := '1')
        is
        begin
            delay_address_in <= to_unsigned(address, 8);
            delay_in <= to_unsigned(delay, 8);
            delay_up_down_n_in <= up_down_n;
            delay_strobe_in <= '1';
            loop
                clk_wait;
                delay_strobe_in <= '0';
                exit when delay_ack_out;
            end loop;
            delay_address_in <= (others => 'U');
            delay_in <= (others => 'U');
            delay_up_down_n_in <= 'U';
        end;

    begin
        delay_strobe_in <= '0';
        ck_valid <= '1';
        ck_reset_in <= '1';
        reset_fifo_in <= "00";
        delay_reset_ca_in <= '1';
        delay_reset_dq_rx_in <= '1';
        delay_reset_dq_tx_in <= '1';

        wait for 50 ns;
        ck_reset_in <= '0';

        wait until ck_ok_out;
        delay_reset_ca_in <= '0';
        delay_reset_dq_rx_in <= '0';
        delay_reset_dq_tx_in <= '0';

        clk_wait(10);

        write_delay(2#1111_0000#, 5);       -- CA TX 0 += 6
        write_delay(2#1000_0001#, 7);       -- DQ Bitslip 1 += 8
        write_delay(2#0000_0010#, 6);       -- DQ RX 2 += 7
        write_delay(2#0100_0010#, 12);      -- DQ TX 2 += 13
        clk_wait;
        write_delay(2#0100_0011#, 9);       -- DQ TX 3 += 10
        write_delay(2#0100_0011#, 9, '0');  -- DQ TX 3 -= 10

        wait;
    end process;


    -- Generate toggling data on CA and DQ output
    process (ck_clk) begin
        if rising_edge(ck_clk) then
            ca_in(0) <= not ca_in(0);
            data_in <= not data_in;
        end if;
    end process;
end;
