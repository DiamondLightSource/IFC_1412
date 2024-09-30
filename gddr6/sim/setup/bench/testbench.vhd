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
    signal reg_clk_in : std_ulogic := '0';

    signal ck_reset_out : std_ulogic;
    signal ck_clk_in : std_ulogic := '0';
    signal ck_clk_ok_in : std_ulogic;

    signal write_strobe_in : std_ulogic_vector(GDDR6_REGS_RANGE);
    signal write_data_in : reg_data_array_t(GDDR6_REGS_RANGE);
    signal write_ack_out : std_ulogic_vector(GDDR6_REGS_RANGE);
    signal read_strobe_in : std_ulogic_vector(GDDR6_REGS_RANGE);
    signal read_data_out : reg_data_array_t(GDDR6_REGS_RANGE);
    signal read_ack_out : std_ulogic_vector(GDDR6_REGS_RANGE);

    signal phy_ca_out : phy_ca_t;
    signal phy_ca_in : phy_ca_t;
    signal phy_output_enable : std_ulogic;
    signal phy_dq_out : phy_dq_out_t;
    signal phy_dq_in : phy_dq_in_t;
    signal phy_dbi_n_out : vector_array(7 downto 0)(7 downto 0);
    signal phy_dbi_n_in : vector_array(7 downto 0)(7 downto 0);

    signal phy_setup_out : phy_setup_t;
    signal phy_status_in : phy_status_t;
    signal setup_delay_out : setup_delay_t;
    signal setup_delay_in : setup_delay_result_t;
    signal enable_controller_out : std_ulogic;

begin
    reg_clk_in <= not reg_clk_in after 2.3 ns;

    ck_clk_in <= not ck_clk_in after 2 ns when not ck_reset_out;
    ck_clk_ok_in <= not ck_reset_out;

    setup : entity work.gddr6_setup port map (
        reg_clk_i => reg_clk_in,

        write_strobe_i => write_strobe_in,
        write_data_i => write_data_in,
        write_ack_o => write_ack_out,
        read_strobe_i => read_strobe_in,
        read_data_o => read_data_out,
        read_ack_o => read_ack_out,

        ck_reset_o => ck_reset_out,
        ck_clk_i => ck_clk_in,
        ck_clk_ok_i => ck_clk_ok_in,

        phy_ca_o => phy_ca_out,
        phy_ca_i => phy_ca_in,
        phy_output_enable_i => phy_output_enable,
        phy_dq_o => phy_dq_out,
        phy_dq_i => phy_dq_in,
        phy_dbi_n_o => phy_dbi_n_out,
        phy_dbi_n_i => phy_dbi_n_in,

        phy_setup_o => phy_setup_out,
        phy_status_i => phy_status_in,

        setup_delay_o => setup_delay_out,
        setup_delay_i => setup_delay_in,

        enable_controller_o => enable_controller_out
    );

    process (ck_clk_in) begin
        if rising_edge(ck_clk_in) then
            if phy_dq_out.output_enable then
                phy_dq_in.data <= (others => (others => '1'));
            else
                phy_dq_in.data <= phy_dq_out.data;
            end if;
        end if;
    end process;

    phy_status_in <= (
        fifo_ok => "11"
    );
    setup_delay_in <= (
        write_ack => '1',
        read_ack => '1',
        delay => (others => '0')
    );

    process
        procedure clk_wait(count : natural := 1) is
        begin
            clk_wait(reg_clk_in, count);
        end;

        procedure write_reg(reg : natural; value : reg_data_t) is
        begin
            write_reg(
                reg_clk_in, write_data_in, write_strobe_in, write_ack_out,
                reg, value);
        end;

        procedure read_reg(reg : natural) is
        begin
            read_reg(
                reg_clk_in, read_data_out, read_strobe_in, read_ack_out,
                reg);
        end;

        procedure read_reg_result(reg : natural; result : out reg_data_t) is
        begin
            read_reg_result(
                reg_clk_in, read_data_out, read_strobe_in, read_ack_out,
                reg, result, false);
        end;


        procedure start_write is
        begin
            write_reg(GDDR6_COMMAND_REG, (
                GDDR6_COMMAND_START_WRITE_BIT => '1',
                others => '0'));
        end;

        procedure write_data_word(value : std_ulogic_vector) is
        begin
            write_reg(GDDR6_DQ_REG, value);
        end;

        procedure write_ca(
            ca0 : std_ulogic_vector; ca1 : std_ulogic_vector;
            ca3 : std_ulogic_vector;
            cke_n : std_ulogic;
            output_enable : std_ulogic) is
        begin
            write_reg(GDDR6_CA_REG, (
                GDDR6_CA_RISING_BITS => ca0,
                GDDR6_CA_FALLING_BITS => ca1,
                GDDR6_CA_CA3_BITS => ca3,
                GDDR6_CA_CKE_N_BIT => cke_n,
                GDDR6_CA_OUTPUT_ENABLE_BIT => output_enable,
                others => '0'));
        end;

        procedure do_exchange is
        begin
            write_reg(GDDR6_COMMAND_REG, (
                GDDR6_COMMAND_EXCHANGE_BIT => '1',
                others => '0'));
        end;

        procedure start_read is
        begin
            write_reg(GDDR6_COMMAND_REG, (
                GDDR6_COMMAND_START_READ_BIT => '1',
                others => '0'));
        end;

        procedure step_read is
        begin
            write_reg(GDDR6_COMMAND_REG, (
                GDDR6_COMMAND_STEP_READ_BIT => '1',
                others => '0'));
        end;

        procedure read_data_words(count : natural := 1) is
            variable result : reg_data_t;
        begin
            for i in 1 to count loop
                read_reg_result(GDDR6_DQ_REG, result);
                write("Data: " & to_hstring(result));
            end loop;
            step_read;
        end;

    begin
        write_strobe_in <= (others => '0');
        read_strobe_in <= (others => '0');

        clk_wait(5);
        write_reg(GDDR6_CONFIG_REG, (
            GDDR6_CONFIG_CK_RESET_N_BIT => '1',
            others => '0'));

        start_write;
        write_data_word(X"01234567");
        write_ca(10X"123", 10X"056", X"0", '0', '0');
        write_data_word(X"89ABCDEF");
        write_ca(10X"389", 10X"2BC", X"3", '0', '0');
        write_data_word(X"01010101");
        write_ca(10X"3FF", 10X"3FF", X"F", '0', '0');
        write_ca(10X"3FF", 10X"3FF", X"F", '1', '1');
        write_ca(10X"3FF", 10X"3FF", X"F", '1', '1');
        write_ca(10X"3FF", 10X"3FF", X"F", '1', '1');

        do_exchange;

        -- Read all 7 captured words plus an extra word
        start_read;
        read_data_words;
        read_data_words;
        read_data_words;
        read_data_words(2);
        read_data_words;
        read_data_words;
        read_data_words;

        wait;
    end process;
end;
