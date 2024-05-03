-- Refresh controller.  Generates refresh requests at the required tempo: a
-- complete round of per bank refreshes every 1.9 us, together with a full all
-- bank refresy every millisecond.  Hueristically chooses banks to refresh to
-- avoid interfering with ongoing transfers as much as possible.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_timing_defs.all;
use work.gddr6_ctrl_defs.all;

entity gddr6_ctrl_refresh is
    generic (
        -- These are designed to be overwritten to speed up simulation only
        SHORT_REFRESH_COUNT : natural := t_REFI;
        LONG_REFRESH_COUNT : natural := t_ABREF_REFI
    );
    port (
        clk_i : in std_ulogic;

        -- Status of all banks, used to select appropriate banks for refresh
        status_i : in banks_status_t;
        -- Top level refresh enable asserted during normal operation.  This acts
        -- as a reset when deasserted
        enable_refresh_i : in std_ulogic;
        -- Request to block read/write requests when refresh falling behind
        stall_requests_o : out std_ulogic := '0';
        -- Refresh request with completion handshake
        refresh_request_o : out refresh_request_t := IDLE_REFRESH_REQUEST;
        refresh_ack_i : in std_ulogic
    );
end;

architecture arch of gddr6_ctrl_refresh is
    signal short_counter : natural range 0 to SHORT_REFRESH_COUNT - 1 := 0;
    signal long_counter : natural range 0 to LONG_REFRESH_COUNT - 1 := 0;
    signal refresh_tick : std_ulogic := '0';
    signal full_refresh_tick : std_ulogic := '0';

    -- This refresh delay measures how far we are behind the regular 1.9us tick.
    -- The larger the delay the more urgent is the choice of bank to refresh.
    -- In practice this should never increase above 2, if it reaches 3 we stall
    -- all commands, if it overflows we lose track of refresh and fall behind.
    constant MAX_REFRESH_DELAY : natural := 3;
    constant STALL_REFRESH_DELAY : natural := 3;
    signal refresh_delay : natural range 0 to MAX_REFRESH_DELAY;
    signal do_full_refresh : std_ulogic := '0';

    -- List of bank pairs that still need refresh in this round
    signal needs_refresh : std_ulogic_vector(0 to 7) := (others => '0');
    -- Candidate bank pairs at current stage of refresh
    signal refresh_list : std_ulogic_vector(0 to 7) := (others => '0');
    -- Selected bank pair to refresh (paired with n+8)
    signal refresh_bank : natural range 0 to 7;

    type refresh_state_t is (
        REFRESH_IDLE,       -- Waiting for refresh cycle to start
        REFRESH_START,      -- One tick delay after start to settle pipeline
        REFRESH_NEXT,       -- Select bank to refresh
        REFRESH_ONE,        -- Issue refresh request for selected bank
        REFRESH_ALL,        -- Issue all banks refresh request
        REFRESH_WAIT        -- Wait for outstanding refresh request to complete
    );
    signal refresh_state : refresh_state_t := REFRESH_IDLE;


    function find_set_bit(
        bits : std_ulogic_vector(0 to 7)) return natural is
    begin
        for n in bits'RANGE loop
            if bits(n) then
                return n;
            end if;
        end loop;
        return 0;   -- Should not happen!
    end;

    -- Compute refresh list according to current refresh level.  The idea here
    -- is to first refresh banks that won't interfere with reads and writes
    -- already in progress, and then wait a little to allow a chance for the
    -- busy banks to become free.
    impure function get_refresh_list return std_ulogic_vector is
    begin
        case refresh_delay is
            when 0 =>
                -- During the first stage of refresh we only refresh idle
                -- and old banks.  Both banks of a pair have to be eligible
                return
                    (not status_i.active(0 to 7) or status_i.old(0 to 7)) and
                    (not status_i.active(8 to 15) or status_i.old(8 to 15));
            when 1 =>
                -- During middle refresh only exempt the young
                return not (status_i.young(0 to 7) or status_i.young(8 to 15));
            when others =>
                -- During late refresh noone is exempt
                return (0 to 7 => '1');
        end case;
    end;

begin
    process (clk_i)
        variable start_refresh : std_ulogic;

    begin
        if rising_edge(clk_i) then
            if enable_refresh_i then
                -- Keep track of time, generate a one clock refresh_tick every
                -- refresh interval t_REFI (1.9 microseconds), and a full
                -- refresh once a millisecond
                if short_counter > 0 then
                    short_counter <= short_counter - 1;
                    full_refresh_tick <= '0';
                else
                    short_counter <= SHORT_REFRESH_COUNT - 1;
                    if long_counter > 0 then
                        long_counter <= long_counter - 1;
                    else
                        long_counter <= LONG_REFRESH_COUNT - 1;
                    end if;
                end if;
                refresh_tick <= to_std_ulogic(short_counter = 0);
                full_refresh_tick <= to_std_ulogic(long_counter = 0);
            else
                refresh_tick <= '0';
                full_refresh_tick <= '0';
            end if;


            -- Maintain the count of outstanding refresh calls, this is
            -- incremented on each refresh tick and decremented when picked up
            -- by the refresh state machine
            start_refresh := to_std_ulogic(
                refresh_state = REFRESH_IDLE and refresh_delay > 0);
            if refresh_tick and not start_refresh then
                refresh_delay <= refresh_delay + 1;
            elsif not refresh_tick and start_refresh then
                refresh_delay <= refresh_delay - 1;
            end if;
            -- Similarly ensure the full refresh request is set until seen
            if refresh_tick and full_refresh_tick then
                do_full_refresh <= '1';
            elsif refresh_state = REFRESH_START then
                do_full_refresh <= '0';
            end if;

            -- Issue input stall when we reach the maximum outstanding refresh
            -- count.  We could be more clever about this, but this will work
            -- for now.  This should never normally happen!
            stall_requests_o <=
                to_std_ulogic(refresh_delay >= STALL_REFRESH_DELAY);

            -- Compute list of banks currently eligible for refresh
            refresh_list <= get_refresh_list;

            -- Refresh stage engine.  Wait for a refresh interval to start, and
            -- then loop checking for eligible banks to refresh
            case refresh_state is
                when REFRESH_IDLE =>
                    needs_refresh <= (others => '1');
                    if start_refresh then
                        refresh_state <= REFRESH_START;
                    end if;

                when REFRESH_START =>
                    if do_full_refresh then
                        refresh_state <= REFRESH_ALL;
                    else
                        refresh_state <= REFRESH_NEXT;
                    end if;

                when REFRESH_NEXT =>
                    -- Stall in this state until we can find a free bank
                    if vector_or(refresh_list and needs_refresh) then
                        refresh_bank <=
                            find_set_bit(refresh_list and needs_refresh);
                        refresh_state <= REFRESH_ONE;
                    end if;

                when REFRESH_ONE =>
                    refresh_request_o <= (
                        bank => to_unsigned(refresh_bank, 3),
                        all_banks => '0',
                        priority => to_std_ulogic(refresh_delay > 1),
                        valid => '1'
                    );
                    needs_refresh(refresh_bank) <= '0';
                    refresh_state <= REFRESH_WAIT;

                when REFRESH_ALL =>
                    -- Issue an all banks refresh
                    refresh_request_o <= (
                        bank => "111",
                        all_banks => '1',
                        priority => to_std_ulogic(refresh_delay > 1),
                        valid => '1'
                    );
                    needs_refresh <= (others => '0');
                    refresh_state <= REFRESH_WAIT;

                when REFRESH_WAIT =>
                    -- Wait for outstanding refresh to complete
                    if refresh_ack_i then
                        refresh_request_o.valid <= '0';
                        if vector_or(needs_refresh) then
                            refresh_state <= REFRESH_NEXT;
                        else
                            refresh_state <= REFRESH_IDLE;
                        end if;
                    end if;
            end case;
        end if;
    end process;
end;
