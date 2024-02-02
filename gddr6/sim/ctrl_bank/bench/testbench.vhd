library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

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

    signal write_out : std_ulogic;
    signal read : std_ulogic;
    signal precharge : std_ulogic;
    signal auto_precharge : std_ulogic;

    signal refresh : std_ulogic;
    signal activate : std_ulogic;
    signal row_in : unsigned(13 downto 0);

    type command_t is (NOP, ACT, WR, RD, PRE, REF, INV);
    signal command : command_t := NOP;
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

        write_i => write_out,
        read_i => read,
        precharge_i => precharge,
        auto_precharge_i => auto_precharge,

        refresh_i => refresh,
        activate_i => activate,
        row_i => row_in
    );

    process (all)
        function resolve(a : command_t; b : command_t) return command_t is
        begin
            if a = NOP then
                return b;
            elsif b = NOP then
                return a;
            else
                return INV;
            end if;
        end;

        variable result : command_t;
    begin
        result := NOP;
        if activate and allow_activate then
            result := resolve(result, ACT);
        end if;
        if read and allow_read then
            result := resolve(result, RD);
        end if;
        if write_out and allow_write then
            result := resolve(result, WR);
        end if;
        if precharge and allow_precharge then
            result := resolve(result, PRE);
        end if;
        if refresh and allow_refresh then
            result := resolve(result, REF);
        end if;
        command <= result;

    end process;

    process (clk) begin
        if rising_edge(clk) then
            tick_counter <= tick_counter + 1;
            if command /= NOP then
                interval <= tick_counter - last_counter;
                last_counter <= tick_counter;
                write(
                    "@ " & integer'image(tick_counter) & " " &
                    command_t'image(command) & " +" &
                    integer'image(tick_counter - last_counter) &
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
            signal request : out std_ulogic; signal allow : in std_ulogic) is
        begin
            request <= '1';
            loop
                clk_wait;
                exit when allow;
            end loop;
            request <= '0';
        end;

        procedure do_activate(row : unsigned) is
        begin
            row_in <= row;
            do_handshake(activate, allow_activate);
        end;

        procedure do_precharge is
        begin
            do_handshake(precharge, allow_precharge);
        end;

        procedure do_write(auto : std_ulogic := '0') is
        begin
            auto_precharge <= auto;
            do_handshake(write_out, allow_write);
            auto_precharge <= '0';
        end;

        procedure do_read(auto : std_ulogic := '0') is
        begin
            auto_precharge <= auto;
            do_handshake(read, allow_read);
            auto_precharge <= '0';
        end;

        procedure do_refresh is
        begin
            do_handshake(refresh, allow_refresh);
        end;

    begin
        write_out <= '0';
        read <= '0';
        precharge <= '0';
        auto_precharge <= '0';
        refresh <= '0';
        activate <= '0';

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
