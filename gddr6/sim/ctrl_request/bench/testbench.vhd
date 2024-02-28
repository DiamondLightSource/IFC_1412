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

    signal mux_request : core_request_t := IDLE_CORE_REQUEST;
    signal mux_request_ready : std_ulogic;
    signal write_request_sent : std_ulogic;
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

        mux_request_i => mux_request,
        mux_ready_o => mux_request_ready,

        write_request_sent_o => write_request_sent,
        read_request_sent_o => read_request_sent,

        bank_open_o => bank_open,
        bank_open_ok_i => bank_open_ok,
        bank_open_request_o => bank_open_request,

        out_request_o => out_request,
        out_request_ok_i => out_request_ok,

        command_o => command,
        command_valid_o => command_valid
    );


    -- Test commands
    process
        procedure do_command(
            direction : direction_t;
            bank : natural; row : unsigned;
            command : ca_command_t; precharge : std_ulogic;
            extra : boolean; next_extra : boolean) is
        begin
            mux_request <= (
                direction => direction,
                bank => to_unsigned(bank, 4), row => row,
                command => command, precharge => precharge,
                extra => to_std_ulogic(extra),
                next_extra => to_std_ulogic(next_extra),
                valid => '1');
            loop
                clk_wait;
                exit when mux_request_ready;
            end loop;
            mux_request <= IDLE_CORE_REQUEST;
        end;

        procedure write(
            bank : natural; row : unsigned; column : unsigned;
            precharge : std_ulogic := '0'; extra : natural := 0)
        is
            variable command : ca_command_t;
        begin
            case extra is
                when 0 =>
                    command := SG_WOM(to_unsigned(bank, 4), column);
                when 1 =>
                    command := SG_WDM(to_unsigned(bank, 4), column, "1111");
                when 2 =>
                    command := SG_WSM(to_unsigned(bank, 4), column, "1111");
                when others =>
            end case;
            do_command(
                DIR_WRITE, bank, row, command,
                precharge, false, extra > 0);

            -- Send any mask commands straight after
            for n in extra downto 1 loop
                command := SG_write_mask(X"ABC" & to_std_ulogic_vector_u(n, 4));
                do_command(
                    DIR_WRITE, bank, row, command, '0', true, n > 1);
            end loop;
        end;

        procedure read(
            bank : natural; row : unsigned; column : unsigned;
            precharge : std_ulogic := '0') is
        begin
            do_command(
                DIR_READ, bank, row, SG_RD(to_unsigned(bank, 4), column),
                precharge, false, false);
        end;

    begin
        mux_request <= IDLE_CORE_REQUEST;

        clk_wait(5);
        write(3, 14X"1234", 7X"01");
        write(4, 14X"1234", 7X"02");
        write(4, 14X"1234", 7X"03", extra => 1);
        write(5, 14X"1234", 7X"04", extra => 2);
        write(6, 14X"1234", 7X"05", extra => 2);
        write(7, 14X"1234", 7X"06");
        write(8, 14X"1234", 7X"07");
        write(10, 14X"1234", 7X"08");
        read(3, 14X"1234", 7X"01");
        read(4, 14X"1234", 7X"02");
        read(5, 14X"1234", 7X"03");
        read(6, 14X"1234", 7X"04");
        read(7, 14X"1234", 7X"05");
        read(8, 14X"1234", 7X"06");

        wait;
    end process;


    bank_open_ok <= bank_open.valid;
    out_request_ok <= out_request.valid;


    -- Decode CA commands and print
    decode : entity work.decode_commands generic map (
        REPORT_NOP => true
    ) port map (
        clk_i => clk,
        valid_i => command_valid,
        ca_command_i => command
    );
end;
