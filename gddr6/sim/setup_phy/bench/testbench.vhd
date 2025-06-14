library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.gddr6_register_defines.all;
use work.gddr6_defs.all;

use work.sim_support.all;

entity testbench is
end testbench;


architecture arch of testbench is
    constant CK_FREQUENCY : real := 250.0;
    constant ENABLE_DELAY_READBACK : boolean := true;

    constant CK_WIDTH : time := 1 us / CK_FREQUENCY;
    constant WCK_WIDTH : time := CK_WIDTH / 4;

    signal ck_clock_running : boolean := true;

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

    signal setup_trigger : std_ulogic := '0';
    signal ctrl_setup : ctrl_setup_t;
    signal ctrl_ca : phy_ca_t;
    signal ctrl_dq_in : phy_dq_out_t;
    signal ctrl_dq_out : phy_dq_in_t;
    signal temperature_in : sg_temperature_t;

    signal clk : std_ulogic := '0';

    signal write_strobe : std_ulogic_vector(GDDR6_REGS_RANGE);
    signal write_data : reg_data_array_t(GDDR6_REGS_RANGE);
    signal write_ack : std_ulogic_vector(GDDR6_REGS_RANGE);
    signal read_strobe : std_ulogic_vector(GDDR6_REGS_RANGE);
    signal read_data : reg_data_array_t(GDDR6_REGS_RANGE);
    signal read_ack : std_ulogic_vector(GDDR6_REGS_RANGE);

begin
    clk <= not clk after 2 ns;

    test : entity work.setup_phy port map (
        reg_clk_i => clk,

        write_strobe_i => write_strobe,
        write_data_i => write_data,
        write_ack_o => write_ack,
        read_strobe_i => read_strobe,
        read_data_o => read_data,
        read_ack_o => read_ack,

        setup_trigger_i => setup_trigger,

        ctrl_setup_o => ctrl_setup,
        ctrl_ca_i => ctrl_ca,
        ctrl_dq_i => ctrl_dq_in,
        ctrl_dq_o => ctrl_dq_out,
        temperature_i => temperature_in,

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
    pad_SG12_CK_P <= not pad_SG12_CK_P after CK_WIDTH / 2 when ck_clock_running;
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

        procedure start_write(quiet : boolean := false) is
        begin
            write_reg(GDDR6_COMMAND_REG, (
                GDDR6_COMMAND_START_WRITE_BIT => '1',
                others => '0'), quiet);
        end;

        procedure do_exchange(
            start_read : std_ulogic := '1'; quiet : boolean := false) is
        begin
            write_reg(GDDR6_COMMAND_REG, (
                GDDR6_COMMAND_EXCHANGE_BIT => '1',
                GDDR6_COMMAND_START_READ_BIT => start_read,
                others => '0'), quiet);
        end;

        procedure write_ca(
            oe : std_ulogic := '0';
            rising : std_ulogic_vector(9 downto 0) := 10X"3FF";
            falling : std_ulogic_vector(9 downto 0) := 10X"3FF";
            ca3 : std_ulogic_vector(3 downto 0) := X"0";
            cke_n : std_ulogic := '1'; quiet : boolean := false) is
        begin
            write_reg(GDDR6_CA_REG, (
                GDDR6_CA_RISING_BITS => rising,
                GDDR6_CA_FALLING_BITS => falling,
                GDDR6_CA_CA3_BITS => ca3,
                GDDR6_CA_CKE_N_BIT => cke_n,
                GDDR6_CA_OUTPUT_ENABLE_BIT => oe,
                others => '0'), quiet => quiet);
        end;


        variable read_result : reg_data_t;
        variable read_result2 : reg_data_t;
        variable dq_count : natural;

        procedure write_dq(dq : reg_data_t) is
        begin
            write_reg(GDDR6_DQ_REG, dq);
            write_reg(GDDR6_DQ_REG, dq);
            write_ca(oe => '1');
            dq_count := dq_count + 1;
        end;

        procedure read_dq_edc(n : natural) is
            variable dq : reg_data_t;
            variable edc_in : reg_data_t;
            variable edc_out : reg_data_t;
        begin
            read_reg_result(GDDR6_DQ_REG, dq, true);
            read_reg_result(GDDR6_DBI_REG, edc_out, true);
            read_reg_result(GDDR6_EDC_REG, edc_in, true);
            write(to_string(n) & ": " &
                to_hstring(dq) & " " & to_hstring(edc_in) & " " &
                to_hstring(edc_out));
            write_reg(GDDR6_COMMAND_REG, (
                GDDR6_COMMAND_STEP_READ_BIT => '1',
                others => '0'), true);
        end;

        procedure write_delay(
            target : natural; address : natural; delay : natural;
            write : std_ulogic := '1') is
        begin
            write_reg(GDDR6_DELAY_REG, (
                GDDR6_DELAY_ADDRESS_BITS => to_std_ulogic_vector_u(address, 7),
                GDDR6_DELAY_TARGET_BITS => to_std_ulogic_vector_u(target, 2),
                GDDR6_DELAY_DELAY_BITS => to_std_ulogic_vector_u(delay, 9),
                GDDR6_DELAY_ENABLE_WRITE_BIT => write,
                others => '0'));
        end;

        constant CAPTURE_COUNT : natural := 20;

    begin
        write_strobe <= (others => '0');
        read_strobe <= (others => '0');

        clk_wait(50);
        read_reg(GDDR6_STATUS_REG);

        -- Now take CK out of reset, set RX bitslip
        write_reg(GDDR6_CONFIG_REG, (
            GDDR6_CONFIG_CK_RESET_N_BIT => '1',
            GDDR6_CONFIG_SG_RESET_N_BITS => "01",
            GDDR6_CONFIG_CAPTURE_EDC_OUT_BIT => '1',
            others => '0'));

        -- Wait for locked status
        loop
            read_reg_result(GDDR6_STATUS_REG, read_result, true);
            exit when read_result(GDDR6_STATUS_CK_OK_BIT);
        end loop;
        write("CK locked");

        -- Put EDC into tristate
        write_reg(GDDR6_CONFIG_REG, (
            GDDR6_CONFIG_CK_RESET_N_BIT => '1',
            GDDR6_CONFIG_SG_RESET_N_BITS => "01",
            GDDR6_CONFIG_EDC_T_BIT => '1',
            GDDR6_CONFIG_CAPTURE_EDC_OUT_BIT => '1',
            others => '0'), true);


        -- Configure test exchange
        start_write(quiet => true);
        write_reg(GDDR6_DQ_REG, X"0000_0000", true);
        write_ca('0', 10X"0", 10X"0", X"0", '0', quiet => true);
        write_reg(GDDR6_DQ_REG, X"0000_0000", true);
        write_ca(oe => '1', quiet => true);
        write_reg(GDDR6_DQ_REG, X"0000_0000", true);
        write_ca(oe => '1', quiet => true);
        for i in 1 to 15 loop
            write_ca(quiet => true);
        end loop;
        -- Do exchange
        do_exchange(quiet => true);
        -- Read and print results
        for i in 0 to 17 loop
            read_reg_result(GDDR6_DQ_REG, read_result, true);
            read_reg_result(GDDR6_CA_REG, read_result2, true);
            write_reg(GDDR6_COMMAND_REG, (
                GDDR6_COMMAND_STEP_READ_BIT => '1',
                others => '0'), true);
            write(to_string(i) & ": " &
                to_hstring(read_result) & " " & to_hstring(read_result2));
        end loop;
        wait;


        -- Simple exchange to check CA
        start_write;
        write_ca(cke_n => '0', rising => 10X"155", falling => 10X"2AA");
        write_ca;
        do_exchange;


        -- Perform a complete exchange
        start_write;
        dq_count := 0;

        -- Fill CA and DQ buffer, start with writing two zeros, then padding
        write_dq(X"FFFF_FFFF");
        write_dq(X"0000_0000");
        write_dq(X"0000_0000");
        write_dq(X"5757_5757");
        write_dq(X"AAAA_AAAA");
        write_dq(X"0000_0000");
        write_dq(X"0000_0000");
        write_dq(X"FFFF_FFFF");
        for n in dq_count to CAPTURE_COUNT-1 loop
            write_ca;
        end loop;
        -- Leave the interface running with 55 as output
        write_dq(X"5757_5757");

        -- Perform exchange
        do_exchange;

        write_delay(0, 2, 10);
        write_delay(1, 2, 20);
        write_delay(0, 2, 0, '0');
        read_reg(GDDR6_DELAY_REG);

        -- Read and print results
        for n in 0 to CAPTURE_COUNT-1 loop
            read_dq_edc(n);
        end loop;
        write("Capture complete", true);


        -- Now stop the clocks and try reading the status
        ck_clock_running <= false;
        clk_wait(5);
        read_reg(GDDR6_STATUS_REG);
        -- Restart clock and try reading again
        ck_clock_running <= true;
        read_reg(GDDR6_STATUS_REG);

        wait;
    end process;
end;
