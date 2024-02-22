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

    signal direction : direction_t := DIR_READ;
    signal stall : std_ulogic := '0';
    signal write_request : core_request_t := IDLE_CORE_REQUEST;
    signal write_ready : std_ulogic;
    signal read_request : core_request_t := IDLE_CORE_REQUEST;
    signal read_ready : std_ulogic;
    signal out_request : core_request_t;
    signal out_ready : std_ulogic := '1';

    signal tick_count : natural := 0;
    signal last_request : core_request_t := IDLE_CORE_REQUEST;

    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

    procedure do_request(
        signal request : out core_request_t; signal ready : in std_ulogic;
        direction : direction_t; value : natural;
        extra : std_ulogic := '0'; next_extra : std_ulogic := '0') is
    begin
        request <= (
            direction => direction,
            bank => (others => '0'), row => (others => '0'),
            command => (
                ca => (to_std_ulogic_vector_u(value, 10), (others => '0')),
                ca3 => "0000"),
            precharge => '0',
            extra => extra, next_extra => next_extra, valid => '1');
        loop
            clk_wait;
            exit when ready;
        end loop;
        request <= IDLE_CORE_REQUEST;
    end;

begin
    clk <= not clk after 2 ns;

    request_mux : entity work.gddr6_ctrl_request_mux port map (
        clk_i => clk,

        direction_i => direction,
        stall_i => stall,

        write_request_i => write_request,
        write_ready_o => write_ready,

        read_request_i => read_request,
        read_ready_o => read_ready,

        out_request_o => out_request,
        out_ready_i => out_ready
    );


    -- Write commands
    process
        procedure write_one(
            value : natural; extra : std_ulogic; next_extra : std_ulogic) is
        begin
            do_request(
                write_request, write_ready, DIR_WRITE,
                value, extra, next_extra);
        end;

        procedure write(value : natural; extra : natural := 0) is
        begin
            write_one(value, '0', to_std_ulogic(extra > 0));
            for n in extra downto 1 loop
                write_one(value + 256 * n, '1', to_std_ulogic(n > 1));
            end loop;
        end;

    begin
        write_request <= IDLE_CORE_REQUEST;

        clk_wait(2);

        for n in 0 to 20 loop
            write(n, n mod 3);
        end loop;

--         write(1);
--         write(2, extra => 1);
--         write(3, extra => 1);
--         write(4, extra => 2);
--         write(5, extra => 2);
--         write(6);
--         write(7);
--         write(8);

        wait;
    end process;


    -- Read commands
    process
        procedure read(value : natural) is
        begin
            do_request(read_request, read_ready, DIR_READ, value);
        end;

    begin
        read_request <= IDLE_CORE_REQUEST;

        clk_wait(2);
        for n in 0 to 10 loop
            read(n);
        end loop;
--         read(1);
--         read(2);
--         read(3);
--         read(4);
--         read(5);
--         read(6);

        wait;
    end process;


    -- Keep direction changing to exercise direction lock
    process begin
        clk_wait;
        case direction is
            when DIR_WRITE => direction <= DIR_READ;
            when DIR_READ => direction <= DIR_WRITE;
        end case;
    end process;

    -- Delay on ready state
    process begin
        out_ready <= '1';
        clk_wait(3);
        -- Ensure we don't break a chain of extras
        while out_request.valid and out_request.next_extra loop
            clk_wait;
        end loop;
        out_ready <= '0';
        clk_wait(2);
    end process;


    -- Inject a random stall
    process begin
        stall <= '0';
        clk_wait(7);
        stall <= '1';
        clk_wait(6);
    end process;


    -- Decode outgoing commands
    process (clk) begin
        if rising_edge(clk) then
            if out_request.valid and out_ready then
                write("@ " & to_string(tick_count) & " " &
                    to_string(out_request.direction) & " " &
                    choose(out_request.extra = '1', "x ", "") &
                    to_hstring(out_request.command.ca(0)));

                if out_request.extra then
                    assert
                        out_request.direction = last_request.direction and
                        (out_request.command.ca(0) and 10X"FF") =
                            (last_request.command.ca(0) and 10X"FF")
                    report "Mismatched commands"
                    severity failure;
                end if;

                last_request <= out_request;
            else
                last_request <= IDLE_CORE_REQUEST;
            end if;
            tick_count <= tick_count + 1;
        end if;
    end process;
end;
