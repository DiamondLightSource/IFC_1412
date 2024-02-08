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

    signal active_banks : std_ulogic_vector(15 downto 0);
    signal direction : sg_direction_t;
    signal direction_idle : std_ulogic;
    signal rw_request : rw_bank_request_t;
    signal rw_request_matches : std_ulogic;
    signal rw_request_ready : std_ulogic := '0';
    signal admin_request : bank_admin_t;
    signal admin_ready : std_ulogic;

    signal tick_counter : natural := 0;

    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

begin
    clk <= not clk after 2 ns;

    banks : entity work.gddr6_ctrl_banks port map (
        clk_i => clk,

        active_banks_o => active_banks,
        direction_o => direction,
        direction_idle_o => direction_idle,

        rw_request_i => rw_request,
        rw_request_matches_o => rw_request_matches,
        rw_request_ready_o => rw_request_ready,

        admin_request_i => admin_request,
        admin_ready_o => admin_ready
    );


    process (clk) begin
        if rising_edge(clk) then
            tick_counter <= tick_counter + 1;
        end if;
    end process;


    -- Generate read/write requests
    process
        procedure do_request(
            bank : unsigned(3 downto 0); row : unsigned(13 downto 0);
            direction : sg_direction_t; precharge : std_ulogic := '0';
            extra : natural := 0) is
        begin
            rw_request <= (
                bank => bank,
                row => row,
                direction => direction,
                precharge => precharge,
                extra => to_std_ulogic(extra > 0),
                valid => '1'
            );
            loop
                clk_wait;
                exit when rw_request_ready;
            end loop;
            clk_wait(extra);
            rw_request.extra <= '0';
            rw_request.valid <= '0';
            write("@ " & to_string(tick_counter) & " " &
                "request " & to_string(direction) & " " &
                to_hstring(bank) & " " & to_hstring(row) & " " &
                choose(rw_request_matches = '1', "accepted", "rejected"));
        end;

    begin
        rw_request <= invalid_bank_request;
        clk_wait(5);

--         do_request(4X"3", 14X"1234", DIRECTION_WRITE);
--         clk_wait(2);
--         do_request(4X"3", 14X"1234", DIRECTION_READ);
--         do_request(4X"3", 14X"1234", DIRECTION_READ);
--         do_request(4X"3", 14X"1234", DIRECTION_READ, extra => 2);
--         do_request(4X"3", 14X"1234", DIRECTION_WRITE);
--         do_request(4X"3", 14X"1234", DIRECTION_WRITE);
--         do_request(4X"3", 14X"1234", DIRECTION_WRITE);

        -- Check intervals between commands
        clk_wait(1);
        do_request(4X"0", 14X"0000", DIRECTION_WRITE);

        wait;
    end process;


    -- Generate admin requests
    process
        procedure do_admin(
            command : bank_command_t; bank : unsigned(3 downto 0) := "0000";
            row : unsigned(13 downto 0) := (others => '0');
            all_banks : std_ulogic := '0') is
        begin
            admin_request <= (
                command => command,
                bank => bank,
                row => row,
                all_banks => all_banks,
                valid => '1'
            );
            loop
                clk_wait;
                exit when admin_ready;
            end loop;
            admin_request.valid <= '0';
            write("@ " & to_string(tick_counter) & " " &
                "admin " & to_string(command) & " " &
                to_hstring(bank) & " " & to_hstring(row) & " " &
                choose(all_banks = '1', "all", ""));
        end;

    begin
        admin_request <= invalid_admin_request;
        clk_wait(5);

        -- Check intervals between commands
        do_admin(CMD_ACT, 4X"0", 14X"0000");


--         clk_wait(2);
--         do_admin(CMD_ACT, 4X"3", 14X"1234");
--         do_admin(CMD_ACT, 4X"4", 14X"0678");
--         do_admin(CMD_PRE, 4X"4");
--         do_admin(CMD_PRE, all_banks => '1');
--         do_admin(CMD_REF, all_banks => '1');
--         do_admin(CMD_ACT, 4X"2", 14X"0123");

        wait;
    end process;
end;
