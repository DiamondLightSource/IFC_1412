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
    signal riu_clk_in : std_ulogic := '0';
    signal ck_clk_ok_in : std_ulogic;

    signal write_strobe_in : std_ulogic_vector(GDDR6_REGS_RANGE);
    signal write_data_in : reg_data_array_t(GDDR6_REGS_RANGE);
    signal write_ack_out : std_ulogic_vector(GDDR6_REGS_RANGE);
    signal read_strobe_in : std_ulogic_vector(GDDR6_REGS_RANGE);
    signal read_data_out : reg_data_array_t(GDDR6_REGS_RANGE);
    signal read_ack_out : std_ulogic_vector(GDDR6_REGS_RANGE);

    signal phy_ca_out : vector_array(0 to 1)(9 downto 0);
    signal phy_ca3_out : std_ulogic_vector(0 to 3);
    signal phy_cke_n_out : std_ulogic;
    signal phy_dq_t_out : std_ulogic;
    signal phy_data_out : std_ulogic_vector(511 downto 0);
    signal phy_data_in : std_ulogic_vector(511 downto 0);
    signal phy_edc_in_in : vector_array(7 downto 0)(7 downto 0);
    signal phy_edc_out_in : vector_array(7 downto 0)(7 downto 0);

    signal riu_addr_out : unsigned(9 downto 0);
    signal riu_wr_data_out : std_ulogic_vector(15 downto 0);
    signal riu_rd_data_in : std_ulogic_vector(15 downto 0);
    signal riu_wr_en_out : std_ulogic;
    signal riu_strobe_out : std_ulogic;
    signal riu_ack_in : std_ulogic;
    signal riu_error_in : std_ulogic;
    signal riu_vtc_handshake_out : std_ulogic;

    signal ck_reset_out : std_ulogic;
    signal ck_unlock_in : std_ulogic;
    signal fifo_ok_in : std_ulogic;
    signal sg_resets_out : std_ulogic_vector(0 to 1);
    signal enable_cabi_out : std_ulogic;
    signal enable_dbi_out : std_ulogic;
    signal rx_slip_out : unsigned_array(0 to 1)(2 downto 0);
    signal tx_slip_out : unsigned_array(0 to 1)(2 downto 0);

begin
    reg_clk_in <= not reg_clk_in after 2.3 ns;
    ck_clk_in <= not ck_clk_in after 2 ns;
    riu_clk_in <= not riu_clk_in after 4 ns;
    ck_clk_ok_in <= '1';

    setup : entity work.gddr6_setup port map (
        reg_clk_i => reg_clk_in,
        ck_clk_i => ck_clk_in,
        riu_clk_i => riu_clk_in,
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
        phy_dq_t_o => phy_dq_t_out,
        phy_data_o => phy_data_out,
        phy_data_i => phy_data_in,
        phy_edc_in_i => phy_edc_in_in,
        phy_edc_out_i => phy_edc_out_in,

        riu_addr_o => riu_addr_out,
        riu_wr_data_o => riu_wr_data_out,
        riu_rd_data_i => riu_rd_data_in,
        riu_wr_en_o => riu_wr_en_out,
        riu_strobe_o => riu_strobe_out,
        riu_ack_i => riu_ack_in,
        riu_error_i => riu_error_in,
        riu_vtc_handshake_o => riu_vtc_handshake_out,

        ck_reset_o => ck_reset_out,
        ck_unlock_i => ck_unlock_in,
        fifo_ok_i => fifo_ok_in,
        sg_resets_o => sg_resets_out,
        enable_cabi_o => enable_cabi_out,
        enable_dbi_o => enable_dbi_out,
        rx_slip_o => rx_slip_out,
        tx_slip_o => tx_slip_out
    );

    process (ck_clk_in) begin
        if rising_edge(ck_clk_in) then
            if phy_dq_t_out then
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
            cke_n : std_ulogic; dq_t : std_ulogic) is
        begin
            write_reg(GDDR6_CA_REG, (
                GDDR6_CA_RISING_BITS => ca0,
                GDDR6_CA_FALLING_BITS => ca1,
                GDDR6_CA_CA3_BITS => ca3,
                GDDR6_CA_CKE_N_BIT => cke_n,
                GDDR6_CA_DQ_T_BIT => dq_t,
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
