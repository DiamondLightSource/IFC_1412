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
        sda_io : inout std_logic;

        done_o : out std_ulogic
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
            message : natural; variable ack : inout std_ulogic) is
        begin
            maybe_write_byte(to_std_ulogic_vector_u(message, 8), ack);
        end;


        procedure write_mailbox_bytes(
            message : natural; bytes : data_array_t)
        is
            variable ack : std_ulogic;
        begin
            start;
            write_byte(MB_ADDRESS & '0', ack);
            write_mailbox_address(message, ack);
            for ix in bytes'RANGE loop
                maybe_write_byte(bytes(ix), ack);
            end loop;

            if not ack then
                write("Missing ack", true);
            end if;
            stop;
        end;

        procedure write_mailbox_byte(message : natural; byte : data_t) is
        begin
            write_mailbox_bytes(message, (0 => byte));
        end;


        procedure read_mailbox_bytes(message : natural; count : natural)
        is
            variable ack : std_ulogic;
            variable result : data_t;
        begin
            start;
            write_byte(MB_ADDRESS & '0', ack);
            write_mailbox_address(message, ack);
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

    begin
        done_o <= '0';
        scl_io <= 'H';
        sda_io <= 'H';

        wait for 10 us;

        write_mailbox_bytes(1, (X"9A", X"12"));

        read_mailbox_bytes(1, 8);

        -- Finally write an "offical" MMC transaction: this consists of
        --  message version 0
        --  product 0584 = 1412
        --  version 2
        --  serial 0E8E3245 = 244200005
        --  slot 4
        --  checksum
        write_mailbox_bytes(0, (
            X"00", X"05", X"84", X"02", X"0E", X"8E", X"32", X"45",
            X"04", X"5E"));

        wait for 1 us;
        done_o <= '1';

        wait;
    end process;
end;
