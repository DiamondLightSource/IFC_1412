library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;
use work.register_defs.all;
use work.mailbox_register_defines.all;
use work.sim_support.all;

entity testbench is
end testbench;


architecture arch of testbench is
    constant MB_ADDRESS : std_ulogic_vector(6 downto 0) := 7X"60";

    signal clk : std_ulogic := '0';

    procedure clk_wait(count : natural := 1) is
    begin
        clk_wait(clk, count);
    end;

    -- Helper function for printing an array of bytes
    function to_string(value : vector_array) return string
    is
        variable linebuffer : line;
    begin
        for i in value'RANGE loop
            write(linebuffer, to_hstring(value(i)) & " ");
        end loop;
        return linebuffer.all;
    end;

    -- Renders timestamp prefix in microseconds to 3 decimal places.  This is a
    -- mess, and the alternative to_string(now, unit => us) doesn't generate a
    -- consistent width
    function timestamp_us(t : time) return string is
    begin
        -- This really is a cryptic mess
        return "@ " & to_string(1.0e-3 * real(t / 1 ns), 3) & " us: ";
    end;


    signal write_strobe : std_ulogic;
    signal write_data : reg_data_t;
    signal write_ack : std_ulogic;
    signal read_strobe : std_ulogic;
    signal read_data : reg_data_t;
    signal read_ack : std_ulogic;

    signal scl : std_logic;
    signal sda : std_logic;
    signal i2c_done : std_ulogic;

    signal slot : unsigned(3 downto 0);

begin
    clk <= not clk after 2 ns;


    mailbox : entity work.mailbox generic map (
        MB_ADDRESS => MB_ADDRESS
    ) port map (
        clk_i => clk,

        write_strobe_i => write_strobe,
        write_data_i => write_data,
        write_ack_o => write_ack,
        read_strobe_i => read_strobe,
        read_data_o => read_data,
        read_ack_o => read_ack,

        scl_i => to_x01(scl),
        sda_io => sda,

        slot_o => slot
    );


    -- Simulation of MMC master
    i2c_master : entity work.i2c_master generic map (
        MB_ADDRESS => MB_ADDRESS
    ) port map (
        scl_io => scl,
        sda_io => sda,
        done_o => i2c_done
    );


    -- Register interface to mailbox
    process
        procedure write_reg(
            message : natural; byte : natural;
            data : std_ulogic_vector(7 downto 0);
            quiet : boolean := false) is
        begin
            write_reg(clk, write_data, write_strobe, write_ack, (
                MAILBOX_MSG_ADDR_BITS => to_std_ulogic_vector_u(message, 2),
                MAILBOX_BYTE_ADDR_BITS => to_std_ulogic_vector_u(byte, 4),
                MAILBOX_DATA_BITS => data,
                MAILBOX_WRITE_BIT => '1',
                others => '0'), quiet => true);
            if not quiet then
                write("TX[" &
                    to_string(message) & ", " & to_string(byte) &
                    "] <= " & to_hstring(data),
                    stamp => true);
            end if;
        end;

        procedure read_reg_result(
            message : natural; byte : natural;
            variable result : out std_ulogic_vector;
            quiet : boolean := false)
        is
            variable value : reg_data_t;
        begin
            write_reg(clk, write_data, write_strobe, write_ack, (
                MAILBOX_MSG_ADDR_BITS => to_std_ulogic_vector_u(message, 2),
                MAILBOX_BYTE_ADDR_BITS => to_std_ulogic_vector_u(byte, 4),
                MAILBOX_WRITE_BIT => '0',
                others => '0'), quiet => true);
            read_reg_result(
                clk, read_data, read_strobe, read_ack, value,
                quiet => true);
            result := value(MAILBOX_DATA_BITS);
            if not quiet then
                write("RX[" &
                    to_string(message) & ", " & to_string(byte) & "] => " &
                    to_hstring(result) & " slot: " &
                    to_hstring(value(MAILBOX_SLOT_BITS)),
                    stamp => true);
            end if;
        end;

        procedure read_reg(message : natural; byte : natural) is
            variable result : std_ulogic_vector(7 downto 0);
        begin
            read_reg_result(message, byte, result);
        end;

        procedure read_message(message : natural) is
            variable result : vector_array(0 to 15)(7 downto 0);
            variable linebuffer : line;

        begin
            for i in 0 to 15 loop
                read_reg_result(message, i, result(i), true);
            end loop;
            write(timestamp_us(now) &
                "RX[" & to_string(message) & "] => " & to_string(result));
        end;

        procedure write_message(message : natural; content : vector_array) is
        begin
            for i in content'RANGE loop
                write_reg(message, i, content(i), true);
            end loop;
            write(timestamp_us(now) &
                "TX[" & to_string(message) & "] <= " & to_string(content));
        end;

        variable i2c_value : std_ulogic_vector(7 downto 0);

    begin
        write_strobe <= '0';
        read_strobe <= '0';

        clk_wait(100);

        -- Populate the outgoing message buffers
        write_message(0, (X"01", X"02", X"03", X"04", X"05", X"06"));
        write_message(1, (X"11", X"12", X"13", X"14", X"15", X"16"));

        -- Now wait for I2C to complete
        wait until i2c_done;
        clk_wait;

        -- Read the slot number, should be 4
        read_reg_result(0, 8, i2c_value);
        write("Slot = " & to_hstring(i2c_value));

        -- Read the entire message area
        read_message(0);
        read_message(1);
        read_message(2);
        read_message(3);

        wait;
    end process;
end;
