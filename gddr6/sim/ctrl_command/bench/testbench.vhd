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

    signal write_request : core_request_t;
    signal write_request_ready : std_ulogic;
    signal write_request_sent : std_ulogic;
    signal read_request : core_request_t;
    signal read_request_ready : std_ulogic;
    signal read_request_sent : std_ulogic;
    signal admin_command : banks_admin_t;
    signal admin_command_ready : std_ulogic;
    signal bypass_command : ca_command_t;
    signal bypass_valid : std_ulogic;
    signal refresh_stall : std_ulogic;
    signal priority_mode : std_ulogic := '0';
    signal priority_direction : direction_t := DIR_READ;
    signal bank_open : bank_open_t;
    signal banks_status : banks_status_t;
    signal ca_command : ca_command_t;

    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

    signal tick_count : natural := 0;

begin
    clk <= not clk after 2 ns;

    command : entity work.gddr6_ctrl_command port map (
        clk_i => clk,

        write_request_i => write_request,
        write_request_ready_o => write_request_ready,
        write_request_sent_o => write_request_sent,

        read_request_i => read_request,
        read_request_ready_o => read_request_ready,
        read_request_sent_o => read_request_sent,

        admin_i => admin_command,
        admin_ready_o => admin_command_ready,

        bypass_command_i => bypass_command,
        bypass_valid_i => bypass_valid,

        refresh_stall_i => refresh_stall,
        priority_mode_i => priority_mode,
        priority_direction_i => priority_direction,
        bank_open_o => bank_open,
        banks_status_o => banks_status,

        ca_command_o => ca_command
    );

    priority_mode <= '1';
    priority_direction <= DIR_READ;
    refresh_stall <= '0';
    bypass_valid <= '0';


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
        write(X"3", 14X"1234", 7X"78");
        clk_wait;
        write(X"3", 14X"1234", 7X"79", extra => 1);
        write(X"3", 14X"1234", 7X"7A", extra => 2);
        write(X"3", 14X"1234", 7X"12");
        write(X"3", 14X"1234", 7X"13");
        write(X"3", 14X"1234", 7X"00");

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
        read(X"3", 14X"1234", 7X"78");
        read(X"3", 14X"1234", 7X"12");
        read(X"3", 14X"1234", 7X"00");

        wait;
    end process;


    -- Admin commands
    process
        procedure admin(
            command : admin_command_t; bank : unsigned(3 downto 0);
            row : unsigned(13 downto 0) := (others => '0');
            all_banks : std_ulogic := '0') is
        begin
            admin_command <= (
                command => command,
                bank => bank,
                all_banks => all_banks,
                row => row,
                valid => '1'
            );
            loop
                clk_wait;
                exit when admin_command_ready;
            end loop;
            admin_command <= IDLE_BANKS_ADMIN;
        end;

    begin
        admin_command <= IDLE_BANKS_ADMIN;

        clk_wait(12);
        admin(CMD_ACT, X"3", 14X"1234");

        wait;
    end process;


    -- Decode CA commands and print
    decode : entity work.decode_commands port map (
        clk_i => clk,
        ca_command_i => ca_command,
        tick_count_o => tick_count
    );
end;
