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
    signal out_request_extra : std_ulogic;
    signal refresh_stall : std_ulogic := '0';
    signal command : ca_command_t;
    signal command_valid : std_ulogic;

    signal bank_open_delay : natural := 0;
    signal out_request_delay : natural := 0;

    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

    signal tick_count : natural;
    signal check_command_interval : boolean := true;

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
        out_request_extra_o => out_request_extra,

        command_o => command,
        command_valid_o => command_valid
    );


    -- Test commands
    process
        variable command_count : natural := 0;

        procedure do_command(count : natural) is
        begin
            -- We don't care about the context of most fields
            mux_request <= (
                direction => DIR_WRITE,
                bank => to_unsigned(command_count mod 16, 4),
                row => to_unsigned(command_count mod 2**14, 14),
                command => (
                    ca => (others =>
                        to_std_ulogic_vector_u(command_count mod 2**10, 10)),
                    ca3 => to_std_ulogic_vector_u(count, 4)),
                precharge => '0',
                extra => to_std_ulogic(count > 0),
                next_extra => '0',
                valid => '1'
            );
            loop
                clk_wait;
                exit when mux_request_ready;
            end loop;
            mux_request <= IDLE_CORE_REQUEST;
        end;

        procedure write(extra : natural := 0) is
        begin
            command_count := command_count + 1;
            for n in 0 to extra loop
                do_command(n);
            end loop;
        end;

    begin
        mux_request <= IDLE_CORE_REQUEST;

        bank_open_delay <= 0;
        out_request_delay <= 0;

        clk_wait(2);

        write("No delays");
        write;
        write;
        write(2);
        write(2);
        write(2);
        write;
        write(2);
        write;
        write(1);
        write(2);
        write;
        write(2);
        write(1);
        write;
        clk_wait;
        write;
        clk_wait;
        write;

        clk_wait(10);
        check_command_interval <= false;

        write("Bank delay");
        bank_open_delay <= 2;
        write;
        write;
        write(1);
        write(2);
        write(2);
        write;
        clk_wait(2);
        write;
        clk_wait(2);
        write;

        write("Request delay");
        bank_open_delay <= 0;
        out_request_delay <= 2;
        write;
        write;
        write(1);
        write(2);
        write(2);
        write;
        clk_wait(2);
        write;
        clk_wait(2);
        write;

        clk_wait(10);

        write("Mixed delays");
        bank_open_delay <= 3;
        out_request_delay <= 2;
        write;
        write;
        write(1);
        write(2);
        write(2);
        write;
        clk_wait(2);
        write;
        clk_wait(2);
        write;

        write("Test complete");

        wait;
    end process;


    -- Bank acknowledge after configurable delay
    process begin
        bank_open_ok <= 'U';
        wait until bank_open.valid;
        bank_open_ok <= '0';
        clk_wait(bank_open_delay);
        bank_open_ok <= '1';
        wait until not bank_open.valid;
    end process;

    -- Out acknowledge after configurable delay
    process begin
        out_request_ok <= 'U';
        wait until out_request.valid;
        out_request_ok <= '0';
        clk_wait(out_request_delay);
        out_request_ok <= '1';
        wait until not out_request.valid;
    end process;


    -- Decode and check commands and print
    process (clk)
        variable this_command : natural;
        variable this_extra : natural;
        variable command_delay : natural;

        variable last_tick : natural := 5;      -- Allow for initial setup
        variable last_command : natural := 0;
        variable last_extra : natural := 0;

        function prefix(extra : natural) return string is
        begin
            if extra > 0 then
                return " --- ";
            else
                return " cmd ";
            end if;
        end;

    begin
        if rising_edge(clk) then
            tick_count <= tick_count + 1;
            if command_valid then
                this_command := to_integer(unsigned(command.ca(0)));
                this_extra := to_integer(unsigned(command.ca3));
                command_delay := tick_count - last_tick;

                write("@ " & to_string(tick_count) &
                    prefix(this_extra) & to_string(this_command) &
                    ":" & to_string(this_extra) &
                    " delta " & to_string(command_delay));

                -- Sanity checking
                assert command_delay = 1 or this_extra = 0
                    report "Mask detached from command"
                    severity error;
                assert command_delay >= 2 or this_extra > 0 or last_extra > 0
                    report "Commands too close together"
                    severity error;
                assert this_extra > 0 or this_command - last_command = 1
                    report "Missing or repeated command"
                    severity error;
                assert this_extra = 0 or this_command = last_command
                    report "Extra somehow detached from command"
                    severity error;

                -- Report on commands with excess delay
                if check_command_interval and this_extra = 0 then
                    if command_delay > 2 and last_extra = 0 then
                        write(" command gap " & to_string(command_delay));
                    elsif command_delay > 1 and last_extra > 0 then
                        write(" gap after extra " & to_string(command_delay));
                    end if;
                end if;

                last_tick := tick_count;
                last_command := this_command;
                last_extra := this_extra;
            end if;
        end if;
    end process;
end;
