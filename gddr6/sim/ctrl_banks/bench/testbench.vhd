library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

use work.gddr6_ctrl_defs.all;
use work.gddr6_ctrl_command_defs.all;

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
    signal bank_open : bank_open_t;
    signal bank_open_ok : std_ulogic;
    signal out_request : out_request_t;
    signal out_request_extra : std_ulogic;
    signal out_request_ok : std_ulogic;
    signal admin : banks_admin_t;
    signal admin_ack : std_ulogic;
    signal status : banks_status_t;

    -- Interface to request
    signal mux_request : core_request_t;
    signal mux_ready : std_ulogic;
    signal completion : request_completion_t;
    signal command : ca_command_t;
    signal command_valid : std_ulogic;

    -- The out request needs to be delayed one tick
    signal final_out_request : out_request_t := IDLE_OUT_REQUEST;
    signal final_out_request_ok : std_ulogic := '0';
    signal out_request_extra_delay : std_ulogic := '0';
    signal final_out_request_extra : std_ulogic := '0';

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
        admin_ack_o => admin_ack,
        status_o => status
    );

    request : entity work.gddr6_ctrl_request port map (
        clk_i => clk,

        mux_request_i => mux_request,
        mux_ready_o => mux_ready,
        completion_o => completion,
        bank_open_o => bank_open,
        bank_open_ok_i => bank_open_ok,
        out_request_o => out_request,
        out_request_ok_i => out_request_ok,
        out_request_extra_o => out_request_extra,
        command_o => command,
        command_valid_o => command_valid
    );


    -- Align out requests with admin commands.  This reflects the delays in the
    -- final stage of request processing, including an extra tick of delay to
    -- align the extra command marker
    process (clk) begin
        if rising_edge(clk) then
            final_out_request <= out_request;
            final_out_request_ok <= out_request_ok;
            out_request_extra_delay <= out_request_extra;
            final_out_request_extra <= out_request_extra_delay;
        end if;
    end process;


    -- Generate read/write requests
    process
        procedure send_request(
            bank : natural; row : unsigned; direction : direction_t;
            extra : std_ulogic) is
        begin
            mux_request <= (
                direction => direction,
                write_advance => '0',
                bank => to_unsigned(bank, 4),
                row => row,
                command => SG_NOP,
                next_extra => '0',
                extra => extra,
                valid => '1'
            );
            loop
                clk_wait;
                exit when mux_ready;
            end loop;
            mux_request.valid <= '0';
        end;

        procedure do_request(
            bank : natural; row : unsigned; direction : direction_t;
            extra : natural := 0) is
        begin
            send_request(bank, row, direction, '0');
            for i in 1 to extra loop
                send_request(bank, row, DIR_READ, '1');
            end loop;
        end;

    begin
        mux_request <= IDLE_CORE_REQUEST;
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
        wait_for_tick(47);
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
                exit when admin_ack;
            end loop;
            admin <= IDLE_BANKS_ADMIN;
        end;

    begin
        admin <= IDLE_BANKS_ADMIN;
        clk_wait(5);

        do_admin(CMD_ACT, 1, 14X"0000");
        do_admin(CMD_ACT, 0, 14X"0000");
        do_admin(CMD_ACT, 3, 14X"0000");
        clk_wait;
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
        clk_wait(4);
        do_admin(CMD_PRE, 0);
        do_admin(CMD_ACT, 0, 14X"0000");
        clk_wait(20);

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
                    (admin.valid and admin_ack);
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
            if admin.valid and admin_ack then
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
        expect(CMD_ACT, 6);
        expect(CMD_ACT, 2);     -- t_RRD
        expect(CMD_ACT, 2);
        -- The bank open check adds an unavoidable two extra ticks
        expect(DIR_WRITE, 3);   -- t_RCDWR + bank open check + pipeline delays
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
        expect(CMD_PRE, 12);
        expect(CMD_ACT, 5);
        expect(DIR_READ, 5);
        expect(DIR_READ, 2);
        expect(CMD_PRE, 2);
        expect(CMD_ACT, 5);
        expect(DIR_READ, 5);
        expect(DIR_READ, 2);

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

            if admin.valid and admin_ack then
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
