library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

use work.gddr6_ctrl_command_defs.all;
use work.gddr6_ctrl_core_defs.all;

entity testbench is
end testbench;


architecture arch of testbench is
    signal clk : std_ulogic := '0';

    procedure clk_wait(count : natural := 1) is
    begin
        for i in 1 to count loop
            wait until rising_edge(clk);
        end loop;
    end;

    signal direction : direction_t := DIR_READ;
    signal toggle_direction : boolean := true;
--     signal direction : direction_t := DIR_WRITE;
--     signal toggle_direction : boolean := false;

    signal write_request : core_request_t := IDLE_CORE_REQUEST;
    signal write_request_ready : std_ulogic;
    signal write_request_sent : std_ulogic;
    signal read_request : core_request_t := IDLE_CORE_REQUEST;
    signal read_request_ready : std_ulogic;
    signal read_request_sent : std_ulogic;
    signal bank_open : bank_open_t;
    signal bank_open_ok : std_ulogic := '1';
    signal bank_open_request : std_logic;
    signal out_request : out_request_t;
    signal out_request_ok : std_ulogic := '1';
    signal refresh_stall : std_ulogic := '0';
    signal command : ca_command_t;
    signal command_valid : std_ulogic;

    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

begin
    clk <= not clk after 2 ns;

    request : entity work.gddr6_ctrl_request port map (
        clk_i => clk,

        direction_i => direction,

        write_request_i => write_request,
        write_request_ready_o => write_request_ready,
        write_request_sent_o => write_request_sent,

        read_request_i => read_request,
        read_request_ready_o => read_request_ready,
        read_request_sent_o => read_request_sent,

        bank_open_o => bank_open,
        bank_open_ok_i => bank_open_ok,
        bank_open_request_o => bank_open_request,

        out_request_o => out_request,
        out_request_ok_i => out_request_ok,

        refresh_stall_i => refresh_stall,

        command_o => command,
        command_valid_o => command_valid
    );

--     direction <= DIR_WRITE;


    -- Write commands
    process
        procedure write_one(
            bank : unsigned; row : unsigned; column : unsigned;
            command : ca_command_t; precharge : std_ulogic;
            extra : boolean; next_extra : boolean) is
        begin
            write_request <= (
                direction => DIR_WRITE, bank => bank, row => row,
                command => command, precharge => precharge,
                extra => to_std_ulogic(extra),
                next_extra => to_std_ulogic(next_extra),
                valid => '1');
            loop
                clk_wait;
                exit when write_request_ready;
            end loop;
            write_request <= IDLE_CORE_REQUEST;
        end;

        procedure write(
            bank : unsigned; row : unsigned; column : unsigned;
            precharge : std_ulogic := '0'; extra : natural := 0)
        is
            variable command : ca_command_t;
        begin
            case extra is
                when 0 => command := SG_WOM(bank, column);
                when 1 => command := SG_WDM(bank, column, "1111");
                when 2 => command := SG_WSM(bank, column, "1111");
                when others =>
            end case;
            write_one(bank, row, column, command, precharge, false, extra > 0);

            -- Send any mask commands straight after
            for n in extra downto 1 loop
                command := SG_write_mask(X"ABC" & to_std_ulogic_vector_u(n, 4));
                write_one(bank, row, column, command, precharge, true, n > 1);
            end loop;
        end;

    begin
        write_request <= IDLE_CORE_REQUEST;

        clk_wait(5);
        write(X"3", 14X"1234", 7X"01");
        write(X"4", 14X"1234", 7X"02", extra => 1);
        write(X"5", 14X"1234", 7X"03", extra => 1);
        write(X"6", 14X"1234", 7X"04", extra => 2);
        write(X"7", 14X"1234", 7X"05", extra => 2);
        write(X"8", 14X"1234", 7X"06");
        write(X"9", 14X"1234", 7X"07");
        write(X"A", 14X"1234", 7X"08");

        wait;
    end process;


    -- Read commands
    process
        procedure read(
            bank : unsigned; row : unsigned; column : unsigned;
            precharge : std_ulogic := '0') is
        begin
            read_request <= (
                direction => DIR_READ, bank => bank, row => row,
                command => SG_RD(bank, column), precharge => precharge,
                next_extra => '0', extra => '0', valid => '1');
            loop
                clk_wait;
                exit when read_request_ready;
            end loop;
            read_request <= IDLE_CORE_REQUEST;
        end;

    begin
        read_request <= IDLE_CORE_REQUEST;

        clk_wait(5);
        read(X"3", 14X"1234", 7X"01");
        read(X"3", 14X"1234", 7X"02");
        read(X"3", 14X"1234", 7X"03");
        read(X"3", 14X"1234", 7X"04");
        read(X"3", 14X"1234", 7X"05");
        read(X"3", 14X"1234", 7X"06");

        wait;
    end process;



    -- Bank management
    process (clk)
        variable counter : natural := 4;
    begin
        if rising_edge(clk) then
            if counter > 0 then
                counter := counter - 1;
            else
                counter := 4;
                if toggle_direction then
                    case direction is
                        when DIR_READ => direction <= DIR_WRITE;
                        when DIR_WRITE => direction <= DIR_READ;
                    end case;
                end if;
            end if;
        end if;
    end process;

    -- Bank open handshake
    process begin
        bank_open_ok <= '0';
        loop
            clk_wait;
            exit when bank_open.valid;
        end loop;
        clk_wait;
        bank_open_ok <= '1';
        clk_wait;
    end process;

    -- Bank out handshake
    process begin
        out_request_ok <= '0';
        loop
            clk_wait;
            exit when out_request.valid;
        end loop;
        clk_wait;
        out_request_ok <= '1';
        clk_wait;
    end process;


    -- Decode CA commands and print
    decode : entity work.decode_commands generic map (
        REPORT_NOP => true
    ) port map (
        clk_i => clk,
        valid_i => command_valid,
        ca_command_i => command
    );
end;
