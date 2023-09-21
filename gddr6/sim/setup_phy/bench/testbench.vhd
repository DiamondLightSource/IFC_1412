library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.gddr6_register_defines.all;

use work.sim_support.all;

entity testbench is
end testbench;


architecture arch of testbench is
    constant CK_FREQUENCY : real := 300.0;

    constant CK_WIDTH : time := 1 us / CK_FREQUENCY;
    constant WCK_WIDTH : time := CK_WIDTH / 4;

    signal pad_SG12_CK_P : std_ulogic := '0';
    signal pad_SG12_CK_N : std_ulogic;
    signal pad_SG1_WCK_P : std_ulogic := '0';
    signal pad_SG1_WCK_N : std_ulogic;
    signal pad_SG2_WCK_P : std_ulogic;
    signal pad_SG2_WCK_N : std_ulogic;
    signal pad_SG1_RESET_N : std_ulogic;
    signal pad_SG2_RESET_N : std_ulogic;
    signal pad_SG12_CKE_N : std_ulogic;
    signal pad_SG12_CAL : std_ulogic_vector(2 downto 0);
    signal pad_SG1_CA3_A : std_ulogic;
    signal pad_SG1_CA3_B : std_ulogic;
    signal pad_SG2_CA3_A : std_ulogic;
    signal pad_SG2_CA3_B : std_ulogic;
    signal pad_SG12_CAU : std_ulogic_vector(9 downto 4);
    signal pad_SG12_CABI_N : std_ulogic;
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

    signal ca : vector_array(0 to 1)(9 downto 0);
    signal ca3 : std_ulogic_vector(0 to 3);
    signal cke_n : std_ulogic;
    signal data_in : std_ulogic_vector(511 downto 0);
    signal data_out : std_ulogic_vector(511 downto 0);
    signal dq_t : std_ulogic;
    signal edc_in : vector_array(7 downto 0)(7 downto 0);
    signal edc_out : vector_array(7 downto 0)(7 downto 0);

    signal clk : std_ulogic := '0';

    signal write_strobe : std_ulogic_vector(GDDR6_REGS_RANGE);
    signal write_data : reg_data_array_t(GDDR6_REGS_RANGE);
    signal write_ack : std_ulogic_vector(GDDR6_REGS_RANGE);
    signal read_strobe : std_ulogic_vector(GDDR6_REGS_RANGE);
    signal read_data : reg_data_array_t(GDDR6_REGS_RANGE);
    signal read_ack : std_ulogic_vector(GDDR6_REGS_RANGE);

begin
    clk <= not clk after 2 ns;

    test : entity work.gddr6_setup_phy generic map (
        CK_FREQUENCY => CK_FREQUENCY
    ) port map (
        reg_clk_i => clk,

        write_strobe_i => write_strobe,
        write_data_i => write_data,
        write_ack_o => write_ack,
        read_strobe_i => read_strobe,
        read_data_o => read_data,
        read_ack_o => read_ack,

        ca_i => ca,
        ca3_i => ca3,
        cke_n_i => cke_n,
        data_i => data_in,
        data_o => data_out,
        dq_t_i => dq_t,
        edc_in_o => edc_in,
        edc_out_o => edc_out,

        pad_SG12_CK_P_i => pad_SG12_CK_P,
        pad_SG12_CK_N_i => pad_SG12_CK_N,
        pad_SG1_WCK_P_i => pad_SG1_WCK_P,
        pad_SG1_WCK_N_i => pad_SG1_WCK_N,
        pad_SG2_WCK_P_i => pad_SG2_WCK_P,
        pad_SG2_WCK_N_i => pad_SG2_WCK_N,
        pad_SG1_RESET_N_o => pad_SG1_RESET_N,
        pad_SG2_RESET_N_o => pad_SG2_RESET_N,
        pad_SG12_CKE_N_o => pad_SG12_CKE_N,
        pad_SG12_CAL_o => pad_SG12_CAL,
        pad_SG1_CA3_A_o => pad_SG1_CA3_A,
        pad_SG1_CA3_B_o => pad_SG1_CA3_B,
        pad_SG2_CA3_A_o => pad_SG2_CA3_A,
        pad_SG2_CA3_B_o => pad_SG2_CA3_B,
        pad_SG12_CAU_o => pad_SG12_CAU,
        pad_SG12_CABI_N_o => pad_SG12_CABI_N,
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


    -- Run CK at 300 MHz (we should be so lucky on real hardware)
    pad_SG12_CK_P <= not pad_SG12_CK_P after CK_WIDTH / 2;
    pad_SG12_CK_N <= not pad_SG12_CK_P;
    -- Run WCK at 4 times this frequency
    pad_SG1_WCK_P <= not pad_SG1_WCK_P after WCK_WIDTH / 2;
    pad_SG1_WCK_N <= not pad_SG1_WCK_P;
    pad_SG2_WCK_P <= pad_SG1_WCK_P;
    pad_SG2_WCK_N <= pad_SG1_WCK_N;

    -- Pull ups on all IO lines
    pad_SG1_DQ_A <= (others => 'H');
    pad_SG1_DQ_B <= (others => 'H');
    pad_SG2_DQ_A <= (others => 'H');
    pad_SG2_DQ_B <= (others => 'H');
    pad_SG1_DBI_N_A <= "HH";
    pad_SG1_DBI_N_B <= "HH";
    pad_SG2_DBI_N_A <= "HH";
    pad_SG2_DBI_N_B <= "HH";
    pad_SG1_EDC_A <= "HH";
    pad_SG1_EDC_B <= "HH";
    pad_SG2_EDC_A <= "HH";
    pad_SG2_EDC_B <= "HH";


    process
        procedure clk_wait(count : natural := 1) is
        begin
            clk_wait(clk, count);
        end;

        procedure write_reg(
            reg : natural; value : reg_data_t; quiet : boolean := false) is
        begin
            write_reg(
                clk, write_data, write_strobe, write_ack, reg, value, quiet);
        end;

        procedure read_reg(reg : natural; quiet : boolean := false) is
        begin
            read_reg(clk, read_data, read_strobe, read_ack, reg, quiet);
        end;

        procedure read_reg_result(
            reg : natural; result : out reg_data_t;
            quiet : boolean := false) is
        begin
            read_reg_result(
                clk, read_data, read_strobe, read_ack, reg, result, quiet);
        end;

        variable read_result : reg_data_t;
        variable dq_count : natural;


        procedure write_ca(t : std_ulogic) is
        begin
            write_reg(GDDR6_CA_REG, (
                GDDR6_CA_RISING_BITS => 10X"3FF",
                GDDR6_CA_FALLING_BITS => 10X"3FF",
                GDDR6_CA_CA3_BITS => X"0",
                GDDR6_CA_CKE_N_BIT => '1',
                GDDR6_CA_DQ_T_BIT => t,
                others => '0'));
        end;

        procedure write_dq(dq : reg_data_t) is
        begin
            write_reg(GDDR6_DQ_REG, dq);
            write_reg(GDDR6_DQ_REG, dq);
            write_ca('0');
            dq_count := dq_count + 1;
        end;

        procedure read_dq_edc(n : natural) is
            variable dq : reg_data_t;
            variable edc_in : reg_data_t;
            variable edc_out : reg_data_t;
        begin
            read_reg_result(GDDR6_DQ_REG, dq, true);
            read_reg_result(GDDR6_EDC_IN_REG, edc_in, true);
            read_reg_result(GDDR6_EDC_OUT_REG, edc_out, true);
            write(to_string(n) & ": " &
                to_hstring(dq) & " " & to_hstring(edc_in) & " " &
                to_hstring(edc_out));
            write_reg(GDDR6_COMMAND_REG, (
                GDDR6_COMMAND_STEP_READ_BIT => '1',
                others => '0'), true);
        end;

        constant CAPTURE_COUNT : natural := 20;

    begin
        write_strobe <= (others => '0');
        read_strobe <= (others => '0');

        clk_wait(5);
        read_reg(GDDR6_STATUS_REG);

        -- Now take CK out of reset, set RX bitslip
        write_reg(GDDR6_CONFIG_REG, (
            GDDR6_CONFIG_CK_RESET_N_BIT => '1',
--             GDDR6_CONFIG_RX_SLIP_LOW_BITS => "001",
--             GDDR6_CONFIG_RX_SLIP_HIGH_BITS => "001",
            GDDR6_CONFIG_TX_SLIP_LOW_BITS => "111",
            GDDR6_CONFIG_TX_SLIP_HIGH_BITS => "111",
            others => '0'));

        -- Wait for locked status
        loop
            read_reg_result(GDDR6_STATUS_REG, read_result, true);
            exit when read_result(GDDR6_STATUS_CK_OK_BIT);
        end loop;


        -- Perform a complete exchange
        write_reg(GDDR6_COMMAND_REG, (
            GDDR6_COMMAND_START_WRITE_BIT => '1',
            others => '0'));
        dq_count := 0;

        -- Fill CA and DQ buffer, start with writing two zeros, then padding
        write_dq(X"FFFF_FFFF");
        write_dq(X"0000_0000");
        write_dq(X"0000_0000");
--         write_dq(X"5555_5555");
--         write_dq(X"0000_0000");
--         write_dq(X"AAAA_AAAA");
        write_dq(X"5757_5757");
        write_dq(X"0000_0000");
        write_dq(X"0000_0000");
        write_dq(X"FFFF_FFFF");
        for n in dq_count to CAPTURE_COUNT-1 loop
            write_ca('1');
        end loop;

        -- Perform exchange
        write_reg(GDDR6_COMMAND_REG, (
            GDDR6_COMMAND_EXCHANGE_BIT => '1',
            GDDR6_COMMAND_START_READ_BIT => '1',
            others => '0'));

        -- Read and print results
        for n in 0 to CAPTURE_COUNT-1 loop
            read_dq_edc(n);
        end loop;

        wait;
    end process;
end;
