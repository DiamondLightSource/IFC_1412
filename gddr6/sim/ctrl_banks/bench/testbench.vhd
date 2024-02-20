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

    procedure clk_wait(count : natural := 1) is
    begin
        for i in 1 to count loop
            wait until rising_edge(clk);
        end loop;
    end;

    -- Interface to banks
    signal status : banks_status_t;
    signal request : banks_request_t;
    signal request_accept : std_ulogic;
    signal admin : banks_admin_t;
    signal admin_accept : std_ulogic;

    signal tick_counter : natural := 0;

    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

    function name(direction : direction_t) return string is
    begin
        case direction is
            when DIR_READ => return "READ";
            when DIR_WRITE => return "WRITE";
        end case;
    end;

    function name(command : admin_command_t; all_banks : std_ulogic)
        return string is
    begin
        case command is
            when CMD_ACT => return "ACT";
            when CMD_PRE => return "PRE" & choose(all_banks = '1', "ab", "pb");
            when CMD_REF => return "REF" & choose(all_banks = '1', "ab", "p2b");
        end case;
    end;

    signal verbose : boolean := true;

begin
    clk <= not clk after 2 ns;

    banks : entity work.gddr6_ctrl_banks port map (
        clk_i => clk,

        request_i => request,
        request_accept_o => request_accept,
        admin_i => admin,
        admin_accept_o => admin_accept,
        status_o => status
    );


    process (clk) begin
        if rising_edge(clk) then
            tick_counter <= tick_counter + 1;
        end if;
    end process;


    -- Generate read/write requests
    process
        procedure do_request(
            bank : natural; row : unsigned(13 downto 0);
            direction : direction_t; auto_precharge : std_ulogic := '0';
            extra : natural := 0) is
        begin
            if verbose then
                write("@ " & to_string(tick_counter) & "< " & name(direction));
            end if;

            request <= (
                direction => direction,
                bank => to_unsigned(bank, 4),
                auto_precharge => auto_precharge,
                lock => '0',
                valid => '1'
            );
            loop
                clk_wait;
                exit when request_accept;
            end loop;
            for n in 1 to extra loop
                request.valid <= '0';
                request.lock <= '1';
                clk_wait;
            end loop;
            request <= IDLE_BANKS_REQUEST;

            write("@ " & to_string(tick_counter) & " " &
                name(direction) & " " &
                to_string(bank) & " " & to_hstring(row));
        end;

    begin
        request <= IDLE_BANKS_REQUEST;
        clk_wait(2);

        -- Check intervals between commands
        do_request(2, 14X"0000", DIR_WRITE);
        do_request(2, 14X"0001", DIR_WRITE);
        do_request(2, 14X"0002", DIR_READ);
        do_request(2, 14X"0003", DIR_READ);
        do_request(2, 14X"0004", DIR_WRITE);

        wait;
    end process;


    -- Generate admin requests
    process
        procedure do_admin(
            command : admin_command_t; bank : natural := 0;
            row : unsigned(13 downto 0) := (others => '0');
            all_banks : std_ulogic := '0') is
        begin
            if verbose then
                write("@ " & to_string(tick_counter) & "< " &
                    name(command, all_banks));
            end if;

            admin <= (
                command => command,
                bank => to_unsigned(bank, 4),
                all_banks => all_banks,
                row => row,
                valid => '1'
            );
            loop
                clk_wait;
                exit when admin_accept;
            end loop;
            admin <= IDLE_BANKS_ADMIN;

            write("@ " & to_string(tick_counter) & " " &
                name(command, all_banks) & " " &
                to_string(bank) & " " & to_hstring(row));
        end;

    begin
        admin <= IDLE_BANKS_ADMIN;
        clk_wait(5);

        -- Check intervals between commands
        do_admin(CMD_ACT, 0, 14X"0000");
        do_admin(CMD_ACT, 1, 14X"0001");
        do_admin(CMD_ACT, 2, 14X"0002");
        do_admin(CMD_REF, 3, 14X"0003");
        do_admin(CMD_REF, 4, 14X"0004");
        do_admin(CMD_REF, 5, 14X"0005");
        do_admin(CMD_PRE, 2);
        do_admin(CMD_REF, 2);
        do_admin(CMD_ACT, 2, 14X"0006");
        do_admin(CMD_PRE, 2);
        do_admin(CMD_REF, all_banks => '1');
        do_admin(CMD_ACT, 1, 14X"3FFF");

        wait;
    end process;
end;
