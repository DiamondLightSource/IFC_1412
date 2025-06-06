-- Simple I2C master for testing

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.sim_support.all;

entity i2c_master is
    generic (
        MB_ADDRESS : std_ulogic_vector(6 downto 0)
    );
    port (
        scl_io : inout std_logic;
        sda_io : inout std_logic
    );
end;

architecture arch of i2c_master is
    -- I2C timing constants for SMBus
    constant T_BUF : time := 4.7 us;
    constant T_HD_STA : time := 4.0 us;
    constant T_SU_STA : time := 4.7 us;
    constant T_SU_STO : time := 4.0 us;
    constant T_HD_DAT : time := 0.3 us;
    constant T_SU_DAT : time := 0.25 us;
    constant T_LOW : time := 4.7 us;
    constant T_HIGH : time := 4.0 us;

    subtype address_t is unsigned(10 downto 0);
    subtype data_t is std_ulogic_vector(7 downto 0);
    type data_array_t is array(natural range<>) of data_t;

begin
    process
        -- Records timestamp of last falling clock edge
        variable clock_edge : time;

        function bit_to_i2c(value : std_ulogic) return std_logic is
        begin
            if value then
                return 'H';
            else
                return '0';
            end if;
        end function;

        procedure start
        is
            variable delay : time;
        begin
            assert sda_io = 'H'
                report "SDA not high as required"
                severity warning;

            -- Ensure clock is high if necessary
            if scl_io = '0' then
                wait for clock_edge - now + T_LOW;
                scl_io <= 'H';
                wait for T_BUF;
            end if;

            -- Generate start condition by driving data low and then scl
            sda_io <= '0';
            wait for T_HD_STA;
            scl_io <= '0';
            clock_edge := now;
        end;

        procedure stop is
        begin
            sda_io <= '0';
            wait for clock_edge - now + T_LOW;
            scl_io <= 'H';
            wait for T_SU_STO;
            sda_io <= 'H';
            wait for T_BUF;
        end;

        procedure write_bit(bit : std_ulogic) is
        begin
            wait for clock_edge - now + T_LOW - T_SU_DAT;
            sda_io <= bit_to_i2c(bit);
            wait for T_SU_DAT;
            scl_io <= 'H';
            wait for T_HIGH;
            scl_io <= '0';
            clock_edge := now;
            wait for T_HD_DAT;
            sda_io <= 'H';
        end;

        procedure read_bit(variable bit : out std_ulogic) is
        begin
            sda_io <= 'H';
            wait for clock_edge - now + T_LOW;
            scl_io <= 'H';
            wait for T_HIGH;
            bit := to_x01(sda_io);
            scl_io <= '0';
            clock_edge := now;
            wait for T_HD_DAT;
        end;

        procedure write_byte(
            byte : data_t; variable ack : out std_ulogic)
        is
            variable nak : std_ulogic;
        begin
            for bit in 7 downto 0 loop
                write_bit(byte(bit));
            end loop;
            read_bit(nak);
            ack := not nak;
            write("ack " & to_string(ack));
        end;

        procedure maybe_write_byte(
            byte : data_t; variable ack : inout std_ulogic) is
        begin
            if ack then
                write_byte(byte, ack);
            end if;
        end;

        procedure read_byte(
            variable byte : out data_t; ack : std_ulogic) is
        begin
            for bit in 7 downto 0 loop
                read_bit(byte(bit));
            end loop;
            write_bit(not ack);
        end;

        procedure write_mailbox_address(
            address : address_t; variable ack : inout std_ulogic) is
        begin
            maybe_write_byte(
                5X"00" & std_ulogic_vector(address(10 downto 8)), ack);
            maybe_write_byte(std_ulogic_vector(address(7 downto 0)), ack);
        end;


        procedure write_mailbox_bytes(
            address : address_t; bytes : data_array_t)
        is
            variable ack : std_ulogic;
        begin
            start;
            write_byte(MB_ADDRESS & '0', ack);
            write_mailbox_address(address, ack);
            for ix in bytes'RANGE loop
                maybe_write_byte(bytes(ix), ack);
            end loop;

            if not ack then
                write("Missing ack", true);
            end if;
            stop;
        end;

        procedure write_mailbox_byte(address : address_t; byte : data_t) is
        begin
            write_mailbox_bytes(address, (0 => byte));
        end;


        procedure read_mailbox_bytes(address : address_t; count : natural)
        is
            variable ack : std_ulogic;
            variable result : data_t;
        begin
            start;
            write_byte(MB_ADDRESS & '0', ack);
            write_mailbox_address(address, ack);
            if ack then
                start;
                write_byte(MB_ADDRESS & '1', ack);
                for ix in 1 to count loop
                    read_byte(result, to_std_ulogic(ix < count));
                    write("read " & to_hstring(result));
                end loop;
            else
                write("Missing ack", true);
            end if;
            stop;
        end;

variable dummy : std_ulogic;
    begin
        scl_io <= 'H';
        sda_io <= 'H';

        wait for 10 us;

        write_mailbox_bytes(11X"123", (X"9A", X"12"));

        read_mailbox_bytes(11X"123", 3);

--         write_mailbox_bytes(11X"0", (X"12", X"34"));

        wait;
    end process;
end;
