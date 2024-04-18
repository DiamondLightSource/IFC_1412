library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

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

    -- Interface to banks
    signal bank_open : bank_open_t := IDLE_OPEN_REQUEST;
    signal bank_open_ok : std_ulogic;
    signal out_request : out_request_t := IDLE_OUT_REQUEST;
    signal out_request_extra : std_ulogic := '0';
    signal out_request_ok : std_ulogic;
    signal admin : banks_admin_t;
    signal admin_accept : std_ulogic;
    signal status : banks_status_t;

    -- The out request needs to be delayed one tick
    signal final_out_request : out_request_t := IDLE_OUT_REQUEST;
    signal final_out_request_ok : std_ulogic := '0';
    signal final_out_request_extra : std_ulogic := '0';

    -- Communication channel to request flow simulation.  Request must assign
    -- both test_open and test_out, and wait for load_test.
    signal test_open : bank_open_t;
    signal test_out : out_request_t;
    signal test_out_extra : std_ulogic;
    signal load_test : std_ulogic;

    signal tick_counter : natural := 0;
    signal last_tick : natural := 0;

    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, "@ " & to_string(tick_counter) & " ");
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

    procedure wait_for_tick(target : natural) is
    begin
        while tick_counter < target loop
            clk_wait;
        end loop;
    end;

begin
    clk <= not clk after 2 ns;

    banks : entity work.gddr6_ctrl_banks port map (
        clk_i => clk,

        bank_open_i => bank_open,
        bank_open_ok_o => bank_open_ok,
        out_request_i => out_request,
        out_request_ok_o => out_request_ok,
        out_request_extra_i => out_request_extra,
        admin_i => admin,
        admin_accept_o => admin_accept,
        status_o => status
    );


    -- Emulation of ctrl_request via test_{open,out,ready}
    bank_open <= test_open;
    load_test <=
        (bank_open_ok or not test_open.valid) and
        (out_request_ok or not out_request.valid);
    process (clk) begin
        if rising_edge(clk) then
            if out_request_ok or not out_request.valid then
                -- Only advance out request when previous value consumed
                if bank_open_ok and test_open.valid then
                    out_request <= test_out;
                    out_request_extra <= test_out_extra;
                elsif test_out_extra then
                    out_request.valid <= '0';
                    out_request_extra <= '1';
                else
                    out_request.valid <= '0';
                    out_request_extra <= '0';
                end if;
            end if;

            final_out_request <= out_request;
            final_out_request_ok <= out_request_ok;
            final_out_request_extra <= out_request_extra;
        end if;
    end process;


    -- Generate read/write requests
    process
        procedure do_request(
            bank : natural; row : unsigned; direction : direction_t;
            extra : natural := 0) is
        begin
            test_open <= (
                bank => to_unsigned(bank, 4),
                row => row,
                valid => '1'
            );
            test_out <= (
                direction => direction,
                bank => to_unsigned(bank, 4),
                valid => '1');
            test_out_extra <= '0';
            loop
                clk_wait;
                exit when load_test;
            end loop;
            test_open <= IDLE_OPEN_REQUEST;
            test_out <= IDLE_OUT_REQUEST;
            if extra > 0 then
                test_out_extra <= '1';
                loop
                    clk_wait;
                    exit when out_request_ok;
                end loop;
                for i in 2 to extra loop
                    clk_wait;
                end loop;
                test_out_extra <= '0';
            end if;
        end;

    begin
        test_open <= IDLE_OPEN_REQUEST;
        test_out <= IDLE_OUT_REQUEST;
        test_out_extra <= '0';
        clk_wait(2);

        -- Start with mixing writes to multiple banks interleaved with activate
        do_request(0, 14X"0000", DIR_WRITE);
        do_request(1, 14X"0000", DIR_WRITE, extra => 2);
        do_request(1, 14X"0000", DIR_WRITE, extra => 1);
        do_request(0, 14X"0000", DIR_WRITE);
        -- Write to read turnaround
        do_request(0, 14X"0000", DIR_READ);
        do_request(0, 14X"0000", DIR_READ);
        -- Read to write turnaround
        do_request(1, 14X"0000", DIR_WRITE);

        -- Wait for tWTP test to complete, then do read for tRTP test
        wait_for_tick(48);
        do_request(0, 14X"0000", DIR_READ);
        do_request(5, 14X"2345", DIR_READ);

        -- Now check interactions with precharge and change of bank
        do_request(5, 14X"2345", DIR_READ);
        do_request(5, 14X"2346", DIR_READ);

        -- More checks for conflicts with precharge
        wait_for_tick(165);
        do_request(0, 14X"0000", DIR_READ);
        do_request(0, 14X"0000", DIR_READ);
        do_request(0, 14X"0000", DIR_READ);
        do_request(0, 14X"0000", DIR_READ);


        write("All requests sent");

        wait;
    end process;


    -- Generate admin requests
    process
        procedure do_admin(
            command : admin_command_t; bank : natural := 0;
            row : unsigned(13 downto 0) := (others => '0');
            all_banks : std_ulogic := '0') is
        begin
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
            -- Ensure we don't try to run admin commands back to back
            clk_wait;
        end;

    begin
        admin <= IDLE_BANKS_ADMIN;
        clk_wait(5);

        do_admin(CMD_ACT, 1, 14X"0000");
        do_admin(CMD_ACT, 0, 14X"0000");
        do_admin(CMD_ACT, 3, 14X"0000");
        do_admin(CMD_ACT, 6, 14X"0000");

        -- Run until initial round of read/write tests complete
        wait_for_tick(36);
        -- This precharge tests tWTP
        do_admin(CMD_PRE, 1);
        clk_wait;
        -- and this one tRTP followed by tRP, tRAS, tRFCpb
        do_admin(CMD_PRE, 0);
        do_admin(CMD_ACT, 0, 14X"0001");
        do_admin(CMD_PRE, 0);
        do_admin(CMD_REF, 0);
        do_admin(CMD_ACT, 0, 14X"0001");
        -- Now test tRREFD and more instances of tRRD
        do_admin(CMD_REF, 1);
        do_admin(CMD_REF, 2);
        do_admin(CMD_REF, 4);
        do_admin(CMD_ACT, 5, 14X"2345");

        -- Wait just long enough for reads on this row on bank 5 to complete
        clk_wait(7);

        -- Switch bank 5 to new row
        do_admin(CMD_PRE, 5);
        do_admin(CMD_ACT, 5, 14X"2346");

        -- Now try a full refresh
        do_admin(CMD_PRE, 0, all_banks => '1');
        do_admin(CMD_REF, 0, all_banks => '1');
        do_admin(CMD_ACT, 0, 14X"0000");

        -- Check for conflicts with precharge
        wait_for_tick(165);
        do_admin(CMD_PRE, 0);
        do_admin(CMD_ACT, 0, 14X"0000");
        clk_wait(10);
        do_admin(CMD_PRE, 0);
        do_admin(CMD_ACT, 0, 14X"0000");


        write("All admin sent");

        wait;
    end process;


    -- Check delays and expected sequence of commands
    process
        variable fail_count : natural := 0;

        procedure wait_ready is
            variable ticks : natural := 0;
        begin
            loop
                clk_wait;
                ticks := ticks + 1;
                exit when
                    (final_out_request.valid and final_out_request_ok) or
                    (admin.valid and admin_accept);
                assert ticks < 50
                    report "Looks like we're stuck"
                    severity failure;
            end loop;
        end;

        procedure expect(direction : direction_t; delay : natural := 1) is
            variable delta : natural;
        begin
            wait_ready;
            if final_out_request.valid and final_out_request_ok then
                delta := tick_counter - last_tick;
                if final_out_request.direction /= direction or delta /= delay
                then
                    write("Expected " & name(direction) &
                        " +" & to_string(delay));
                    fail_count := fail_count + 1;
                end if;
            else
                write("Expected read/write command");
                fail_count := fail_count + 1;
            end if;
        end;

        procedure expect(
            command : admin_command_t; delay : natural := 1;
            all_banks : std_ulogic := '0')
        is
            variable delta : natural;
            variable ok : boolean;
        begin
            wait_ready;
            if admin.valid and admin_accept then
                delta := tick_counter - last_tick;
                ok :=
                    admin.command = command and admin.all_banks = all_banks and
                    delta = delay;
                if not ok then
                    write("Expected " & name(command, all_banks) &
                        " +" & to_string(delay));
                    fail_count := fail_count + 1;
                end if;
            else
                write("Expected admin command");
                fail_count := fail_count + 1;
            end if;
        end;

        procedure expect_extra(count : natural := 1) is
        begin
            for n in 1 to count loop
                clk_wait;
                if not final_out_request_extra then
                    write("Expected extra");
                end if;
            end loop;
        end;

    begin
        -- We start the test with three back to back activates followed by
        -- four writes, two with mask data, and then read to write and write to
        -- read turnaround
        expect(CMD_ACT, 5);
        expect(CMD_ACT, 2);     -- t_RRD
        expect(CMD_ACT, 2);
        -- The bank open check adds an unavoidable two extra ticks
        expect(DIR_WRITE, 2);   -- t_RCDWR + bank open check
        -- Activate fits into gap
        expect(CMD_ACT);
        expect(DIR_WRITE);
        expect_extra(2);
        expect(DIR_WRITE, 3);   -- 3 ticks after WSM
        expect_extra;
        expect(DIR_WRITE, 2);
        expect(DIR_READ, 10);   -- t_WTR_time = t_WTR+2+WLmrs
        expect(DIR_READ, 2);
        expect(DIR_WRITE, 8);   -- t_RTW

        -- Now testing bank and precharge interactions
        expect(CMD_PRE, 12);    -- t_WTP
        expect(DIR_READ, 1);
        expect(CMD_PRE, 2);     -- t_RTP
        expect(CMD_ACT, 5);     -- t_RP
        expect(CMD_PRE, 7);     -- t_RAS
        expect(CMD_REF, 5);
        expect(CMD_ACT, 14);    -- t_RFCpb
        expect(CMD_REF, 2);     -- t_RRD
        expect(CMD_REF, 4);     -- t_RREFD
        expect(CMD_REF, 4);
        expect(CMD_ACT, 4);     -- t_RREFD
        -- Finally check read delay
        expect(DIR_READ, 5);    -- t_RCDRD

        -- Reading on successive banks
        expect(DIR_READ, 2);
        expect(CMD_PRE, 2);     -- t_RTP
        expect(CMD_ACT, 5);     -- t_RP
        expect(DIR_READ, 5);    -- t_RCDRD

        -- Refresh of all banks
        expect(CMD_PRE, 2, all_banks => '1');
        expect(CMD_REF, 5, all_banks => '1');     -- t_RP
        expect(CMD_ACT, 29);    -- t_RFCab

        -- Precharge checks
        expect(CMD_PRE, 13);
        expect(CMD_ACT, 5);
        expect(DIR_READ, 5);
        expect(DIR_READ, 2);
        expect(DIR_READ, 2);
        expect(DIR_READ, 2);
        expect(CMD_PRE, 2);
        expect(CMD_ACT, 5);

        -- Check that all timing checks were satisfied
        clk_wait(2);
        write("Active rows: " & to_string(status.active));
        if fail_count = 0 then
            write("All ok");
        else
            write(to_string(fail_count) & " failed timing");
        end if;

        wait;
    end process;


    -- Report all commands
    process (clk)
        impure function delta return string is
        begin
            return "(+" & to_string(tick_counter - last_tick) & ") ";
        end;

        variable report_count : natural := 0;

    begin
        if rising_edge(clk) then
            report_count := 0;

            if final_out_request.valid and final_out_request_ok then
                write(delta &
                    name(final_out_request.direction) & " " &
                    to_hstring(final_out_request.bank));
                report_count := report_count + 1;
                last_tick <= tick_counter;
            end if;

            if admin.valid and admin_accept then
                write(delta &
                    name(admin.command, admin.all_banks) & " " &
                    to_hstring(admin.bank) & " " & to_hstring(admin.row));
                report_count := report_count + 1;
                last_tick <= tick_counter;
            end if;

            if final_out_request_extra then
                write(delta & "extra");
                report_count := report_count + 1;
            end if;

            assert report_count <= 1
                report "Simultaneous overlapping commands"
                severity failure;

            tick_counter <= tick_counter + 1;
        end if;
    end process;
end;
