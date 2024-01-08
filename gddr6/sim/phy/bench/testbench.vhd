library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;

use work.support.all;

use work.gddr6_defs.all;

entity testbench is
end testbench;


architecture arch of testbench is
    -- Base frequency in MHz.  Would like to run at 300 MHz, but this seems to
    -- defeat timing closure across the board for BITSLICE IO!
    constant CK_FREQUENCY : real := 250.0;

    constant CK_PERIOD : time := 1 us / CK_FREQUENCY;
    constant WCK_PERIOD : time := CK_PERIOD / 4;

    procedure write(message : string) is
        variable linebuffer : line;
    begin
        write(linebuffer, "@ " & to_string(now, unit => ns) & ": ");
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;


    signal ck_clk : std_ulogic;
    signal ck_reset_in : std_ulogic;
    signal ck_ok_out : std_ulogic;

    signal phy_setup : phy_setup_t;
    signal phy_status : phy_status_t;

    signal ca_in : vector_array(0 to 1)(9 downto 0);
    signal ca3_in : std_ulogic_vector(0 to 3);
    signal cke_n_in : std_ulogic;
    signal edc_in_out : vector_array(7 downto 0)(7 downto 0);
    signal edc_out_out : vector_array(7 downto 0)(7 downto 0);

    signal data_in : std_ulogic_vector(511 downto 0) := (others => '0');
    signal data_out : std_ulogic_vector(511 downto 0);
    signal edc_out : std_ulogic_vector(63 downto 0);
    signal output_enable_in : std_ulogic := '0';
    signal edc_t_in : std_ulogic := '0';

    signal setup_delay_in : setup_delay_t;
    signal setup_delay_out : setup_delay_result_t;
    constant SETUP_DELAY_IDLE : setup_delay_t := (
        address => (others => 'U'),
        target => (others => 'U'),
        delay => (others => 'U'),
        up_down_n => 'U',
        enable_write => 'U',
        write_strobe => '0',
        read_strobe => '0'
    );

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

    constant T_IDELAY : natural := 0;
    constant T_ODELAY : natural := 1;
    constant T_OBITSLIP : natural := 3;

begin
    phy : entity work.gddr6_phy port map (
        ck_reset_i => ck_reset_in,
        ck_clk_ok_o => ck_ok_out,
        ck_clk_o => ck_clk,

        phy_setup_i => phy_setup,
        phy_status_o => phy_status,

        setup_delay_i => setup_delay_in,
        setup_delay_o => setup_delay_out,

        ca_i => ca_in,
        ca3_i => ca3_in,
        cke_n_i => cke_n_in,

        data_i => data_in,
        data_o => data_out,
        output_enable_i => output_enable_in,
        edc_in_o => edc_in_out,
        edc_out_o => edc_out_out,

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


    pad_SG12_CK_P <= not pad_SG12_CK_P after CK_PERIOD / 2 when ck_valid;
    pad_SG12_CK_N <= not pad_SG12_CK_P;

    pad_SG1_WCK_P <= not pad_SG1_WCK_P after WCK_PERIOD / 2 when ck_ok_out;
    pad_SG1_WCK_N <= not pad_SG1_WCK_P;
    pad_SG2_WCK_P <= not pad_SG1_WCK_P after WCK_PERIOD / 2 when ck_ok_out;
    pad_SG2_WCK_N <= not pad_SG2_WCK_P;

    pad_SG1_DQ_A <= (others => 'H');
    pad_SG1_DQ_B <= (others => 'H');
    pad_SG2_DQ_A <= (others => 'H');
    pad_SG2_DQ_B <= (others => 'H');
    pad_SG1_DBI_N_A <= (others => 'H');
    pad_SG1_DBI_N_B <= (others => 'H');
    pad_SG2_DBI_N_A <= (others => 'H');
    pad_SG2_DBI_N_B <= (others => 'H');
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

        -- Writes selected delay to selected address
        procedure write_delay(
            target : natural; address : natural; delay : natural;
            up_down_n : std_ulogic := '1')
        is
            variable plus_minus : string(1 to 1);
        begin
            setup_delay_in <= (
                address => to_unsigned(address, 7),
                target => to_unsigned(target, 2),
                delay => to_unsigned(delay, 9),
                up_down_n => up_down_n,
                enable_write => '1',
                write_strobe => '1',
                read_strobe => '0'
            );
            loop
                clk_wait;
                setup_delay_in.write_strobe <= '0';
                exit when setup_delay_out.write_ack;
            end loop;
            setup_delay_in <= SETUP_DELAY_IDLE;
            plus_minus := "+" when up_down_n else "-";
            write(
                "delay[" &
                to_string(to_unsigned(target, 2)) & ":" &
                to_string(to_unsigned(address, 7)) &
                "] <= " & plus_minus & to_hstring(to_unsigned(delay, 9)));
        end;

        -- Can be called directly after a write to return the read delay
        procedure readback_delay is
        begin
            setup_delay_in <= (
                address => (others => 'U'),
                target => (others => 'U'),
                delay => (others => 'U'),
                up_down_n => 'U',
                enable_write => 'U',
                write_strobe => '0',
                read_strobe => '1'
            );
            loop
                clk_wait;
                setup_delay_in.read_strobe <= '0';
                exit when setup_delay_out.read_ack;
            end loop;
            setup_delay_in <= SETUP_DELAY_IDLE;
            write("delay => " & to_hstring(setup_delay_out.delay));
        end;

        -- Performs a dummy write to select the address to read followed by a
        -- direct readback
        procedure read_delay(target : natural; address : natural) is
        begin
            write("read " &
                to_string(to_unsigned(target, 2)) & ":" &
                to_string(to_unsigned(address, 7)));
            setup_delay_in <= (
                address => to_unsigned(address, 7),
                target => to_unsigned(target, 2),
                delay => (others => 'U'),
                up_down_n => '0',   -- Must be valid for ODELAY
                enable_write => '0',
                write_strobe => '1',
                read_strobe => '0'
            );
            loop
                clk_wait;
                setup_delay_in.write_strobe <= '0';
                exit when setup_delay_out.write_ack;
            end loop;
            setup_delay_in <= SETUP_DELAY_IDLE;
            readback_delay;
        end;

    begin
        setup_delay_in <= SETUP_DELAY_IDLE;

        ck_valid <= '1';
        ck_reset_in <= '1';
        phy_setup <= (
            reset_fifo => "00",
            sg_resets_n => "00",
            enable_cabi => '0',
            enable_dbi => '0',
            capture_dbi => '0',
            edc_delay => 5X"00",
            edc_tri => '0',
            fudge_sticky_ca6 => '0',
            disable_vtc => '0'
        );

        ca_in <= (others => (others => '1'));
        ca3_in <= X"0";
        cke_n_in <= '1';
        data_in <= (others => '1');
        output_enable_in <= '0';

        wait for 50 ns;
        ck_reset_in <= '0';

        wait until ck_ok_out;

        clk_wait(10);


        -- Test alignment of DQ and OE.  Test pattern sequence is:
        --  ck  |   |   |   |   |   |   |   |
        --  d    FF  00  00  FF  00  00  FF
        --  oe   0   0   1   1   1   0   0
        data_in <= (8 => '1', others => '0');
        clk_wait;
        output_enable_in <= '1';
        clk_wait;
        clk_wait;
        data_in <= (8 => '0', others => '1');
        clk_wait;
        data_in <= (8 => '1', others => '0');
        clk_wait;
        output_enable_in <= '0';
        clk_wait;
        data_in <= (8 => '0', others => '1');
        clk_wait;


        -- Test pattern for CA
        cke_n_in <= '0';
        ca_in <= (0 => 10X"155", 1 => 10X"2AA");
        clk_wait;
        ca_in <= (10X"000", 10X"000");
        ca3_in <= X"5";
        clk_wait;
        ca_in <= (10X"000", 10X"000");
        ca3_in <= X"0";
        cke_n_in <= '1';

        phy_setup.edc_tri <= '1';

        write_delay(T_OBITSLIP, 1, 7);      -- DQ Bitslip 1 = 7
        readback_delay;
        read_delay(T_IDELAY, 2);            -- Starts equal to 8 (initial cal?)
        write_delay(T_IDELAY, 2, 6);        -- DQ RX 2 += 7
        readback_delay;
        write_delay(T_ODELAY, 2, 12);       -- DQ TX 2 += 13
        readback_delay;
        clk_wait;
        write_delay(T_ODELAY, 3, 9);        -- DQ TX 3 += 10
        readback_delay;
        write_delay(T_ODELAY, 3, 9, '0');   -- DQ TX 3 -= 10
        readback_delay;

        read_delay(T_OBITSLIP, 1);          -- Should be 7
        read_delay(T_IDELAY, 2);            -- Now expect 15 (8 + 7)
        read_delay(T_ODELAY, 2);            -- Should be 13 (00D)
        read_delay(T_ODELAY, 3);            -- Should be 0

        clk_wait;
        output_enable_in <= '1';
        clk_wait;
        output_enable_in <= '0';
        data_in <= (others => '0');
        clk_wait;
        data_in <= (others => '1');

        wait;
    end process;
end;
