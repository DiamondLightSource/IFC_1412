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

    constant SHORT_REFRESH_COUNT : natural := 50;
    constant LONG_REFRESH_COUNT : natural := 10;

    signal status : banks_status_t;
    signal enable_refresh : std_ulogic;
    signal stall_requests : std_ulogic;
    signal refresh_request : refresh_request_t;
    signal refresh_ready : std_ulogic;

    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

    signal tick_counter : natural := 0;

    signal verbose : boolean := false;

begin
    clk <= not clk after 2 ns;

    refresh : entity work.gddr6_ctrl_refresh generic map (
        SHORT_REFRESH_COUNT => SHORT_REFRESH_COUNT,
        LONG_REFRESH_COUNT => LONG_REFRESH_COUNT
    ) port map (
        clk_i => clk,
        status_i => status,
        enable_refresh_i => enable_refresh,
        stall_requests_o => stall_requests,
        refresh_request_o => refresh_request,
        refresh_ready_i => refresh_ready
    );

    enable_refresh <= '1';
    status <= (
        write_active => 'U',
        read_active => 'U',
        active => (0 to 5 => '1', others => '0'),
        row => (others => (others => 'U')),
        young => (0 | 3 => '1', others => '0'),
        old => (5 => '1', others => '0')
    );

    process begin
        refresh_ready <= '1';
        wait until refresh_request.valid;
        clk_wait;
        refresh_ready <= '0';
        clk_wait(5);
    end process;

    -- Report refresh requests
    process (clk)
        variable refresh_seen : std_ulogic_vector(0 to 7) := (others => '0');
        variable bank : natural;
    begin
        if rising_edge(clk) then
            if refresh_request.valid and refresh_ready then
                if verbose then
                    write("@ " & to_string(tick_counter) & " " &
                        "refresh " & to_hstring(refresh_request.bank) &
                        choose(refresh_request.all_banks = '1', " all", ""));
                elsif refresh_request.all_banks then
                    write("@ " & to_string(tick_counter) & " refresh all");
                end if;

                if refresh_request.all_banks then
                    -- Can only trigger all banks refresh when all banks ready
                    assert not vector_or(refresh_seen) severity failure;
                else
                    bank := to_integer(refresh_request.bank);
                    assert not refresh_seen(bank) severity failure;
                    refresh_seen(bank) := '1';
                    if vector_and(refresh_seen) then
                        refresh_seen := (others => '0');
                    end if;
                end if;
            end if;
            tick_counter <= tick_counter + 1;
        end if;
    end process;
end;
