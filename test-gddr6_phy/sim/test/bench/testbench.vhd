library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.register_defines.all;
use work.gddr6_register_defines.all;
use work.version.all;

use work.sim_support.all;

entity testbench is
end testbench;


architecture arch of testbench is
    constant CK_FREQUENCY : real := 250.0;

    constant CK_WIDTH : time := 1 us / CK_FREQUENCY;
    constant WCK_WIDTH : time := CK_WIDTH / 4;

    signal pad_LMK_CTL_SEL : std_ulogic;
    signal pad_LMK_SCL : std_ulogic;
    signal pad_LMK_SCS_L : std_ulogic;
    signal pad_LMK_SDIO : std_logic;
    signal pad_LMK_RESET_L : std_ulogic;
    signal pad_LMK_SYNC : std_logic;
    signal pad_LMK_STATUS : std_logic_vector(0 to 1);
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

    signal clk : std_ulogic := '0';

    signal regs_write_strobe : std_ulogic;
    signal regs_write_address : unsigned(13 downto 0);
    signal regs_write_data : std_ulogic_vector(31 downto 0);
    signal regs_write_ack : std_ulogic;
    signal regs_read_strobe : std_ulogic;
    signal regs_read_address : unsigned(13 downto 0);
    signal regs_read_data : std_ulogic_vector(31 downto 0);
    signal regs_read_ack : std_ulogic;

    -- Gather CA and CKE from pads
    signal ca : std_ulogic_vector(9 downto 0);
    signal cke_n : std_ulogic;

begin
    clk <= not clk after 2 ns;

    test : entity work.test_gddr6_phy generic map (
        CK_FREQUENCY => CK_FREQUENCY
    ) port map (
        clk_i => clk,

        regs_write_strobe_i => regs_write_strobe,
        regs_write_address_i => regs_write_address,
        regs_write_data_i => regs_write_data,
        regs_write_ack_o => regs_write_ack,
        regs_read_strobe_i => regs_read_strobe,
        regs_read_address_i => regs_read_address,
        regs_read_data_o => regs_read_data,
        regs_read_ack_o => regs_read_ack,

        pad_LMK_CTL_SEL_o => pad_LMK_CTL_SEL,
        pad_LMK_SCL_o => pad_LMK_SCL,
        pad_LMK_SCS_L_o => pad_LMK_SCS_L,
        pad_LMK_SDIO_io => pad_LMK_SDIO,
        pad_LMK_RESET_L_o => pad_LMK_RESET_L,
        pad_LMK_SYNC_io => pad_LMK_SYNC,
        pad_LMK_STATUS_io => pad_LMK_STATUS,

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

    pad_LMK_SDIO <= 'H';
    pad_LMK_STATUS <= "LL";

    -- Run CK at 300 MHz (we should be so lucky on real hardware)
    pad_SG12_CK_P <= not pad_SG12_CK_P after CK_WIDTH / 2;
    pad_SG12_CK_N <= not pad_SG12_CK_P;
    -- Run WCK at 4 times this frequency
    pad_SG1_WCK_P <= not pad_SG1_WCK_P after WCK_WIDTH / 2;
    pad_SG1_WCK_N <= not pad_SG1_WCK_P;
    pad_SG2_WCK_P <= pad_SG1_WCK_P;
    pad_SG2_WCK_N <= pad_SG1_WCK_N;
    -- Pull ups on all lines
    pad_SG1_EDC_A <= "HH";
    pad_SG1_EDC_B <= "HH";
    pad_SG2_EDC_A <= "HH";
    pad_SG2_EDC_B <= "HH";


    -- Gather CA values
    ca <= (
        2 downto 0 => pad_SG12_CAL,
        3 => pad_SG1_CA3_A,         -- Choose one
        9 downto 4 => pad_SG12_CAU
    );
    cke_n <= pad_SG12_CKE_N;


    process
        procedure clk_wait(count : natural := 1) is
        begin
            clk_wait(clk, count);
        end;

        procedure write_reg(reg : natural; value : reg_data_t) is
        begin
            write_reg(
                clk, regs_write_data, regs_write_address, regs_write_strobe,
                regs_write_ack, reg, value);
        end;

        procedure write_gddr6_reg(reg : natural; value : reg_data_t) is
        begin
            write_reg(reg + SYS_GDDR6_REGS'LOW, value);
        end;

        procedure read_reg(reg : natural) is
        begin
            read_reg(
                clk, regs_read_data, regs_read_address, regs_read_strobe,
                regs_read_ack, reg);
        end;

        procedure read_gddr6_reg(reg : natural) is
        begin
            read_reg(reg + SYS_GDDR6_REGS'LOW);
        end;

        procedure read_reg_result(
            reg : natural; result : out reg_data_t; quiet : boolean := false) is
        begin
            read_reg_result(
                clk, regs_read_data, regs_read_address, regs_read_strobe,
                regs_read_ack, reg, result);
        end;

        procedure read_gddr6_reg_result(
            reg : natural; result : out reg_data_t; quiet : boolean := false) is
        begin
            read_reg_result(reg + SYS_GDDR6_REGS'LOW, result, quiet);
        end;

        variable read_result : reg_data_t;


        procedure write_dq_ca(dq : reg_data_t; oe : std_ulogic) is
        begin
            write_gddr6_reg(GDDR6_DQ_REG, dq);
            write_gddr6_reg(GDDR6_CA_REG, (
                GDDR6_CA_RISING_BITS => 10X"3FF",
                GDDR6_CA_FALLING_BITS => 10X"3FF",
                GDDR6_CA_CA3_BITS => X"0",
                GDDR6_CA_CKE_N_BITS => "11",
                GDDR6_CA_OUTPUT_ENABLE_BIT => oe,
                others => '0'));
        end;

        procedure read_dq_edc is
            variable dq : reg_data_t;
            variable edc_in : reg_data_t;
            variable edc_out : reg_data_t;
        begin
            read_gddr6_reg_result(GDDR6_DQ_REG, dq, true);
            read_gddr6_reg_result(GDDR6_EDC_IN_REG, edc_in, true);
            read_gddr6_reg_result(GDDR6_EDC_OUT_REG, edc_out, true);
            write(
                to_hstring(dq) & " " & to_hstring(edc_in) & " " &
                to_hstring(edc_out));
            write_gddr6_reg(GDDR6_COMMAND_REG, (
                GDDR6_COMMAND_STEP_READ_BIT => '1',
                others => '0'));
        end;


        procedure start_write is
        begin
            write_gddr6_reg(GDDR6_COMMAND_REG, (
                GDDR6_COMMAND_START_WRITE_BIT => '1',
                others => '0'));
        end;

        procedure do_exchange(start_read : std_ulogic := '0') is
        begin
            write_gddr6_reg(GDDR6_COMMAND_REG, (
                GDDR6_COMMAND_EXCHANGE_BIT => '1',
                GDDR6_COMMAND_START_READ_BIT => start_read,
                others => '0'));
        end;

        procedure write_ca(
            oe : std_ulogic := '0';
            rising : std_ulogic_vector(9 downto 0) := 10X"3FF";
            falling : std_ulogic_vector(9 downto 0) := 10X"3FF";
            ca3 : std_ulogic_vector(3 downto 0) := X"0";
            cke_n : std_ulogic_vector(1 downto 0) := "11") is
        begin
            write_gddr6_reg(GDDR6_CA_REG, (
                GDDR6_CA_RISING_BITS => rising,
                GDDR6_CA_FALLING_BITS => falling,
                GDDR6_CA_CA3_BITS => ca3,
                GDDR6_CA_CKE_N_BITS => cke_n,
                GDDR6_CA_OUTPUT_ENABLE_BIT => oe,
                others => '0'));
        end;

    begin
        regs_write_strobe <= '0';
        regs_read_strobe <= '0';

        clk_wait(5);
        read_gddr6_reg(GDDR6_STATUS_REG);

        -- Now take CK out of reset
        write_gddr6_reg(GDDR6_CONFIG_REG, (
            GDDR6_CONFIG_CK_RESET_N_BIT => '1',
            others => '0'));

        -- Try an LMK transaction
        write_reg(SYS_LMK04616_REG, (
            SYS_LMK04616_ADDRESS_BITS => 15X"0123",
            SYS_LMK04616_R_WN_BIT => '1',
            SYS_LMK04616_SELECT_BIT => '1',
            others => '0'));
        read_reg(SYS_LMK04616_REG);

        -- Wait for locked status
        loop
            read_gddr6_reg_result(GDDR6_STATUS_REG, read_result);
            exit when read_result(GDDR6_STATUS_CK_OK_BIT);
        end loop;

        -- Bring SG2 out of reset
        start_write;
        write_ca(rising => 10B"1111_10_10_10", falling => 10B"1111_10_10_10");
        do_exchange;
        write_gddr6_reg(GDDR6_CONFIG_REG, (
            GDDR6_CONFIG_CK_RESET_N_BIT => '1',
            GDDR6_CONFIG_SG_RESET_N_BITS => "10",
            others => '0'));

        -- Pull CKE_n low and hold NOP command
        start_write;
        write_ca(cke_n => "00");
        do_exchange;

        -- Wait for t_INIT2 + t_INIT3 (faked)
        clk_wait(10);

        -- Write MRS CA Training command.  Write it twice, leave CKE_N low with
        -- NOP running
        start_write;
        write_ca(
            rising => 10B"10_1111_0100", falling => 10B"10_1111_0100",
            cke_n => "00");
        write_ca(
            rising => 10B"10_1111_0100", falling => 10B"10_1111_0100",
            cke_n => "00");
        write_ca(cke_n => "00");
        do_exchange;

        clk_wait(10);

        -- Write a test pattern
        start_write;
        write_ca(rising => 10X"296", falling => 10X"25A", cke_n => "11");
        write_ca(cke_n => "00");
        do_exchange;

--         -- Perform a complete exchange
--         write_gddr6_reg(GDDR6_COMMAND_REG, (
--             GDDR6_COMMAND_START_WRITE_BIT => '1',
--             others => '0'));
--         -- Fill CA and DQ buffer, start with writing two zeros, then padding
--         for n in 0 to 1 loop
--             write_dq_ca(X"0000_0000", '1');
--         end loop;
--         for n in 2 to 18 loop
--             write_dq_ca(X"FFFF_FFFF", '0');
--         end loop;
--         -- Perform exchange
--         write_gddr6_reg(GDDR6_COMMAND_REG, (
--             GDDR6_COMMAND_EXCHANGE_BIT => '1',
--             GDDR6_COMMAND_START_READ_BIT => '1',
--             others => '0'));
--         -- Read and print results
--         for n in 0 to 18 loop
--             read_dq_edc;
--         end loop;

        wait;
    end process;
end;
