library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

use work.gddr6_ctrl_core_defs.all;

entity testbench is
end testbench;


architecture arch of testbench is
    signal clk : std_ulogic := '0';

    signal active : std_ulogic;
    signal row_out : unsigned(13 downto 0);

    signal allow_activate : std_ulogic;
    signal allow_read : std_ulogic;
    signal allow_write : std_ulogic;
    signal allow_precharge : std_ulogic;
    signal allow_refresh : std_ulogic;

    signal command : bank_command_t;
    signal command_valid : std_ulogic := '0';
    signal auto_precharge : std_ulogic;
    signal row_in : unsigned(13 downto 0);

    type command_t is (NOP, ACT, WR, RD, PRE, REF);
    signal action : command_t := NOP;

    signal tick_counter : natural := 0;
    signal last_counter : natural := 0;
    signal interval : natural := 0;

    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

begin
    clk <= not clk after 2 ns;

    bank : entity work.gddr6_ctrl_bank port map (
        clk_i => clk,

        active_o => active,
        row_o => row_out,

        allow_activate_o => allow_activate,
        allow_read_o => allow_read,
        allow_write_o => allow_write,
        allow_precharge_o => allow_precharge,
        allow_refresh_o => allow_refresh,

        command_i => command,
        command_valid_i => command_valid,
        auto_precharge_i => auto_precharge,
        row_i => row_in
    );


    process (all)
        variable this_action : command_t;
        variable allowed : std_ulogic;
    begin
        if command_valid then
            case command is
                when CMD_ACT => this_action := ACT; allowed := allow_activate;
                when CMD_WR =>  this_action := WR;  allowed := allow_write;
                when CMD_RD =>  this_action := RD;  allowed := allow_read;
                when CMD_PRE => this_action := PRE; allowed := allow_precharge;
                when CMD_REF => this_action := REF; allowed := allow_refresh;
            end case;
            if allowed then
                action <= this_action;
            else
                action <= NOP;
            end if;
        else
            action <= NOP;
        end if;
    end process;

    process (clk) begin
        if rising_edge(clk) then
            tick_counter <= tick_counter + 1;
            if action /= NOP then
                interval <= tick_counter - last_counter;
                last_counter <= tick_counter;
                write(
                    "@ " & to_string(tick_counter) & " " &
                    to_string(action) & " +" &
                    to_string(tick_counter - last_counter) &
                    choose(auto_precharge = '1', " auto", ""));
            end if;
        end if;
    end process;


    process
        procedure clk_wait(count : natural := 1) is
        begin
            for i in 1 to count loop
                wait until rising_edge(clk);
            end loop;
        end;

        procedure do_handshake(
            request : bank_command_t; signal allow : in std_ulogic) is
        begin
            command <= request;
            command_valid <= '1';
            loop
                clk_wait;
                exit when allow;
            end loop;
            command_valid <= '0';
        end;

        procedure do_activate(row : unsigned) is
        begin
            row_in <= row;
            do_handshake(CMD_ACT, allow_activate);
        end;

        procedure do_precharge is
        begin
            do_handshake(CMD_PRE, allow_precharge);
        end;

        procedure do_write(auto : std_ulogic := '0') is
        begin
            auto_precharge <= auto;
            do_handshake(CMD_WR, allow_write);
            auto_precharge <= '0';
        end;

        procedure do_read(auto : std_ulogic := '0') is
        begin
            auto_precharge <= auto;
            do_handshake(CMD_RD, allow_read);
            auto_precharge <= '0';
        end;

        procedure do_refresh is
        begin
            do_handshake(CMD_REF, allow_refresh);
        end;

    begin
        auto_precharge <= '0';
        command_valid <= '0';

        clk_wait(2);

        do_activate(14X"1234");

        do_read;
        do_read;
        do_read;

        do_precharge;

        do_refresh;

        do_activate(14X"3210");

        do_write;
        do_write;
        do_write('1');

        do_refresh;

        do_activate(14X"1678");

        wait;
    end process;
end;
