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
    signal admin : banks_admin_t;

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

        request_i => request,
        admin_i => admin,
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
            direction : sg_direction_t; auto_precharge : std_ulogic := '0';
            extra : natural := 0)
        is
            variable ready : std_ulogic;
        begin
            compute_strobe(
                request.read, bank, to_std_ulogic(direction = DIR_READ));
            compute_strobe(
                request.write, bank, to_std_ulogic(direction = DIR_WRITE));
            request.auto_precharge <= auto_precharge;
            loop
                clk_wait;
                ready :=
                    vector_and(not request.read or status.allow_read) and
                    vector_and(not request.write or status.allow_write);
                exit when ready;
            end loop;
            clk_wait(extra);
            request <= IDLE_BANKS_REQUEST;

            write("@ " & to_string(tick_counter) & " " &
                "request " & to_string(direction) & " " &
                to_string(bank) & " " & to_hstring(row));
        end;

    begin
        request <= IDLE_BANKS_REQUEST;
        clk_wait(2);

        -- Check intervals between commands
        do_request(0, 14X"0000", DIR_WRITE);
        do_request(0, 14X"0000", DIR_WRITE);
        do_request(0, 14X"0000", DIR_READ);
        do_request(0, 14X"0000", DIR_READ);
        do_request(0, 14X"0000", DIR_WRITE);

        wait;
    end process;


    -- Generate admin requests
    process
        type command_t is (CMD_ACT, CMD_PRE, CMD_REF, CMD_PREab, CMD_REFab);

        procedure do_admin(
            command : command_t; bank : natural := 0;
            row : unsigned(13 downto 0) := (others => '0'))
        is
            variable ready : std_ulogic;
        begin
            compute_strobe(
                admin.activate, bank, to_std_ulogic(command = CMD_ACT));
            compute_strobe(
                admin.precharge, bank, to_std_ulogic(command = CMD_PRE));
            compute_strobe(
                admin.refresh, bank, to_std_ulogic(command = CMD_REF));
            admin.precharge_all <= to_std_ulogic(command = CMD_PREab);
            admin.refresh_all <= to_std_ulogic(command = CMD_REFab);
            admin.row <= row;

            loop
                clk_wait;
                ready :=
                    vector_and(not admin.activate or status.allow_activate)
                and
                    vector_and(not admin.refresh or status.allow_refresh)
                and
                    vector_and(not admin.precharge or status.allow_precharge)
                and
                    (not admin.precharge_all or status.allow_precharge_all)
                and
                    (not admin.refresh_all or status.allow_refresh_all);
                exit when ready;
            end loop;
            admin <= IDLE_BANKS_ADMIN;

            write("@ " & to_string(tick_counter) & " " &
                "admin " & to_string(command) & " " &
                to_string(bank) & " " & to_hstring(row));
        end;

    begin
        admin <= IDLE_BANKS_ADMIN;
        clk_wait(5);

        -- Check intervals between commands
        do_admin(CMD_ACT, 0, 14X"0000");
        do_admin(CMD_PRE, 0);
        do_admin(CMD_REF, 0);
        do_admin(CMD_ACT, 0, 14X"0000");
        do_admin(CMD_PRE, 0);
        do_admin(CMD_REFab, 0);
        do_admin(CMD_ACT, 1, 14X"3FFF");

        wait;
    end process;
end;
