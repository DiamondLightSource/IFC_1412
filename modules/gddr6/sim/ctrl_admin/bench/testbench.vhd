library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

use work.gddr6_ctrl_command_defs.all;
use work.gddr6_ctrl_defs.all;

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

    signal bank_open : bank_open_t;
    signal lookahead : bank_open_t;
    signal refresh : refresh_request_t;
    signal refresh_ack : std_ulogic;
    signal status : banks_status_t;
    signal admin : banks_admin_t;
    signal admin_ack : std_ulogic;
    signal command : ca_command_t;
    signal command_valid : std_ulogic;

    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

    signal tick_counter : natural := 0;

begin
    clk <= not clk after 2 ns;

    ctrl_admin : entity work.gddr6_ctrl_admin port map (
        clk_i => clk,

        bank_open_i => bank_open,
        lookahead_i => lookahead,
        refresh_i => refresh,
        refresh_ack_o => refresh_ack,

        status_i => status,

        admin_o => admin,
        admin_ack_i => admin_ack,

        command_o => command,
        command_valid_o => command_valid
    );

    process
        procedure do_refresh(bank : natural; all_banks : std_ulogic) is
        begin
            refresh <= (
                bank => to_unsigned(bank, 3),
                all_banks => all_banks,
                priority => '0',
                valid => '1');
            loop
                clk_wait;
                exit when refresh_ack;
            end loop;
            refresh.valid <= '0';
        end;

    begin
        bank_open <= IDLE_OPEN_REQUEST;
        lookahead <= IDLE_OPEN_REQUEST;
        refresh <= IDLE_REFRESH_REQUEST;

        clk_wait(2);
        bank_open <= (bank => X"3", row => 14X"1234", valid => '1');
        clk_wait(5);
        lookahead <= (bank => X"4", row => 14X"3333", valid => '1');
        bank_open.valid <= '0';
        clk_wait;
        bank_open <= (bank => X"4", row => 14X"1234", valid => '1');
        clk_wait(5);
        do_refresh(4, '0');
        do_refresh(0, '1');

        wait;
    end process;

    process
        variable bank : natural;

    begin
        status <= (
            write_active => '0',
            read_active => '1',
            active => (4 => '1', others => '0'),
            row => (others => (others => '0')),
            young => (others => '0'),
            old => (others => '0')
        );

        loop
            clk_wait;
            if admin.valid and admin_ack then
                bank := to_integer(admin.bank);
                case admin.command is
                    when CMD_ACT =>
                        assert not status.active(bank)
                            report "Bank already active";
                        status.active(bank) <= '1';
                        status.row(bank) <= admin.row;
                    when CMD_PRE =>
                        if admin.all_banks then
                            status.active <= (others => '0');
                        else
                            status.active(bank) <= '0';
                        end if;
                        status.row(bank) <= (others => 'U');
                    when CMD_REF =>
                        if admin.all_banks then
                            assert not vector_or(status.active)
                                report "Bank still active";
                        else
                            assert not status.active(bank) and not
                                status.active(bank + 8)
                                report "Bank still active";
                        end if;
                end case;
            end if;
        end loop;

        wait;
    end process;

    process begin
        admin_ack <= '1';
        wait until admin.valid;
        clk_wait;
        admin_ack <= '0';
        clk_wait(5);
    end process;

    -- Report admin commands
    process (clk)
        function name(command : admin_command_t; all_banks : std_ulogic)
            return string is
        begin
            case command is
                when CMD_ACT =>
                    return "ACT";
                when CMD_PRE =>
                    return "PRE" & choose(all_banks = '1', "ab", "pb");
                when CMD_REF =>
                    return "REF" & choose(all_banks = '1', "ab", "p2b");
            end case;
        end;

    begin
        if rising_edge(clk) then
            if admin.valid and admin_ack then
                write("@ " & to_string(tick_counter) & " " &
                    name(admin.command, admin.all_banks) & " " &
                    to_hstring(admin.bank) & " " & to_hstring(admin.row));
            end if;
            tick_counter <= tick_counter + 1;
        end if;
    end process;
end;
