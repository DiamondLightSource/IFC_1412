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
    signal reg_clk_in : std_ulogic := '0';
    signal ck_clk_in : std_ulogic := '0';
    signal ck_clk_ok_in : std_ulogic;

    signal write_strobe_in : std_ulogic_vector(GDDR6_REGS_RANGE);
    signal write_data_in : reg_data_array_t(GDDR6_REGS_RANGE);
    signal write_ack_out : std_ulogic_vector(GDDR6_REGS_RANGE);
    signal read_strobe_in : std_ulogic_vector(GDDR6_REGS_RANGE);
    signal read_data_out : reg_data_array_t(GDDR6_REGS_RANGE);
    signal read_ack_out : std_ulogic_vector(GDDR6_REGS_RANGE);

    signal phy_ca_out : vector_array(0 to 1)(9 downto 0);
    signal phy_ca3_out : std_ulogic_vector(0 to 3);
    signal phy_cke_n_out : std_ulogic_vector(0 to 1);
    signal phy_output_enable_out : std_ulogic;
    signal phy_data_out : std_ulogic_vector(511 downto 0);
    signal phy_data_in : std_ulogic_vector(511 downto 0);
    signal phy_edc_in_in : vector_array(7 downto 0)(7 downto 0);
    signal phy_edc_out_in : vector_array(7 downto 0)(7 downto 0);

    signal delay_address_out : unsigned(7 downto 0);
    signal delay_out : unsigned(8 downto 0);
    signal delay_up_down_n_out : std_ulogic;
    signal delay_byteslip_out : std_ulogic;
    signal delay_read_write_n_out : std_ulogic;
    signal delay_in : unsigned(8 downto 0);
    signal delay_strobe_out : std_ulogic;
    signal delay_ack_in : std_ulogic;
    signal delay_reset_ca_out : std_ulogic;
    signal delay_reset_dq_rx_out : std_ulogic;
    signal delay_reset_dq_tx_out : std_ulogic;

    signal ck_reset_out : std_ulogic;
    signal ck_unlock_in : std_ulogic;
    signal reset_fifo_out : std_ulogic_vector(0 to 1);
    signal fifo_ok_in : std_ulogic_vector(0 to 1);
    signal sg_resets_n_out : std_ulogic_vector(0 to 1);
    signal edc_t_out : std_ulogic;
    signal enable_cabi_out : std_ulogic;
    signal enable_dbi_out : std_ulogic;
    signal capture_dbi_out : std_ulogic;
    signal edc_delay_out : unsigned(4 downto 0);

begin
    reg_clk_in <= not reg_clk_in after 2.3 ns;
    ck_clk_in <= not ck_clk_in after 2 ns;
    ck_clk_ok_in <= '1';

    setup : entity work.gddr6_setup port map (
        reg_clk_i => reg_clk_in,
        ck_clk_i => ck_clk_in,
        ck_clk_ok_i => ck_clk_ok_in,

        write_strobe_i => write_strobe_in,
        write_data_i => write_data_in,
        write_ack_o => write_ack_out,
        read_strobe_i => read_strobe_in,
        read_data_o => read_data_out,
        read_ack_o => read_ack_out,

        phy_ca_o => phy_ca_out,
        phy_ca3_o => phy_ca3_out,
        phy_cke_n_o => phy_cke_n_out,
        phy_output_enable_o => phy_output_enable_out,
        phy_data_o => phy_data_out,
        phy_data_i => phy_data_in,
        phy_edc_in_i => phy_edc_in_in,
        phy_edc_out_i => phy_edc_out_in,

        delay_address_o => delay_address_out,
        delay_o => delay_out,
        delay_up_down_n_o => delay_up_down_n_out,
        delay_byteslip_o => delay_byteslip_out,
        delay_read_write_n_o => delay_read_write_n_out,
        delay_i => delay_in,
        delay_strobe_o => delay_strobe_out,
        delay_ack_i => delay_ack_in,
        delay_reset_ca_o => delay_reset_ca_out,
        delay_reset_dq_rx_o => delay_reset_dq_rx_out,
        delay_reset_dq_tx_o => delay_reset_dq_tx_out,

        ck_reset_o => ck_reset_out,
        ck_unlock_i => ck_unlock_in,
        reset_fifo_o => reset_fifo_out,
        fifo_ok_i => fifo_ok_in,
        sg_resets_n_o => sg_resets_n_out,
        edc_t_o => edc_t_out,
        enable_cabi_o => enable_cabi_out,
        enable_dbi_o => enable_dbi_out,
        capture_dbi_o => capture_dbi_out,
        edc_delay_o => edc_delay_out
    );

    process (ck_clk_in) begin
        if rising_edge(ck_clk_in) then
            if phy_output_enable_out then
                phy_data_in <= (others => '1');
            else
                phy_data_in <= phy_data_out;
            end if;
        end if;
    end process;


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
            cke_n : std_ulogic_vector(1 downto 0);
            output_enable : std_ulogic) is
        begin
            write_reg(GDDR6_CA_REG, (
                GDDR6_CA_RISING_BITS => ca0,
                GDDR6_CA_FALLING_BITS => ca1,
                GDDR6_CA_CA3_BITS => ca3,
                GDDR6_CA_CKE_N_BITS => cke_n,
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
        start_write;
        write_data_word(X"01234567");
        write_ca(10X"123", 10X"056", X"0", "00", '0');
        write_data_word(X"89ABCDEF");
        write_ca(10X"389", 10X"2BC", X"3", "00", '0');
        write_data_word(X"01010101");
        write_ca(10X"3FF", 10X"3FF", X"F", "00", '0');
        write_ca(10X"3FF", 10X"3FF", X"F", "11", '1');
        write_ca(10X"3FF", 10X"3FF", X"F", "11", '1');
        write_ca(10X"3FF", 10X"3FF", X"F", "11", '1');

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
