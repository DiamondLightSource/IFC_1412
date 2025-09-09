-- Control and state of a single bank

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_defs.all;
use work.gddr6_ctrl_timing_defs.all;
use work.gddr6_ctrl_tuning_defs.all;

entity gddr6_ctrl_bank is
    port (
        clk_i : in std_ulogic;

        -- Current state
        active_o : out std_ulogic := '0';   -- Set if activated
        row_o : out unsigned(13 downto 0);  -- Selected row when activated
        young_o : out std_ulogic := '0';    -- Set if young and active
        old_o : out std_ulogic;             -- Set if old but still active

        -- Permissions, driven by state and timers
        allow_activate_o : out std_ulogic := '1';
        allow_refresh_o : out std_ulogic := '1';
        allow_read_o : out std_ulogic := '0';
        allow_write_o : out std_ulogic := '0';
        allow_precharge_o : out std_ulogic := '1';

        -- Incoming requests, will be acted on when corresponding allow is set
        request_activate_i : in std_ulogic;
        request_refresh_i : in std_ulogic;
        request_read_i : in std_ulogic;
        request_write_i : in std_ulogic;
        request_precharge_i : in std_ulogic;

        -- Row to set for CMD_ACT
        row_i : in unsigned(13 downto 0);

        -- This flag will hold banks in extended refresh
        refresh_all_i : in std_ulogic
    );
end;

architecture arch of gddr6_ctrl_bank is
    signal age : unsigned(OLD_BANK_BITS downto 0) := (others => '0');

    type row_state_t is (BANK_IDLE, BANK_REFRESH, BANK_ACTIVE, BANK_PRECHARGE);
    signal state : row_state_t := BANK_IDLE;

    -- Internal permissions for read and write before qualification by active
    -- state
    signal allow_read : std_ulogic := '0';
    signal allow_write : std_ulogic := '0';

    -- Counters for delays longer than 2 ticks.  The actual delays here are
    -- rather tricky to assign because it is necessary to take account of both
    -- external delays and skews.  In particular, read/write commands are
    -- presented one tick earlier than activate/precharge/refresh commands.
    --
    -- ACT to RD (5)
    signal tRCDRD_counter : natural range 0 to t_RCDRD - 4 := 0;
    -- ACT to PRE (7)
    signal tRAS_counter : natural range 0 to t_RAS - 3 := 0;
    -- WxM to PRE (12)
    signal tWTP_counter : natural range 0 to t_WTP - 2 := 0;
    -- PRE to ACT (5)
    signal tRP_counter : natural range 0 to t_RP - 3 := 0;
    -- REF to ACT (14)
    signal tRFCpb_counter : natural range 0 to t_RFCpb - 3 := 0;

begin
    process (clk_i)
        procedure do_bank_idle is
        begin
            if allow_refresh_o and request_refresh_i then
                tRFCpb_counter <= t_RFCpb - 3;
                allow_precharge_o <= '0';
                state <= BANK_REFRESH;
            elsif allow_activate_o and request_activate_i then
                tRCDRD_counter <= t_RCDRD - 4;
                tRAS_counter <= t_RAS - 3;
                tWTP_counter <= 0;
                row_o <= row_i;
                age <= (others => '0');
                young_o <= '1';
                active_o <= '1';
                allow_write <= '1';
                allow_precharge_o <= '0';
                state <= BANK_ACTIVE;
            end if;
        end;

        procedure do_bank_refresh is
        begin
            if tRFCpb_counter > 0 then
                tRFCpb_counter <= tRFCpb_counter - 1;
            elsif not refresh_all_i then
                allow_precharge_o <= '1';
                state <= BANK_IDLE;
            end if;
        end;

        -- Process ACTIVE state: enable read/write/precharge, transition to
        -- PRECHARGE when requested
        procedure do_bank_active is
            variable do_write : std_ulogic;
            variable do_read : std_ulogic;
            variable do_precharge : std_ulogic;

        begin
            -- Decode the command requests
            do_write := allow_write_o and request_write_i;
            do_read := allow_read_o and request_read_i;
            do_precharge := allow_precharge_o and request_precharge_i;

            if do_read or do_write or do_precharge then
                -- We include precharge just to leave the age of an idle bank
                -- in a well defined state to reduce confusion
                age <= (others => '0');
                young_o <= not do_precharge;
            elsif age(OLD_BANK_BITS) = '0' then
                age <= age + 1;
                young_o <=
                    not vector_or(age(OLD_BANK_BITS downto YOUNG_BANK_BITS));
            end if;

            -- The tRAS, tRCDRD, and tRCDWR timer run from entry into
            -- BANK_ACTIVE state, but tRCDWR is only one tick so is implicit
            if tRAS_counter > 0 then
                tRAS_counter <= tRAS_counter - 1;
            end if;
            if tRCDRD_counter > 0 then
                tRCDRD_counter <= tRCDRD_counter - 1;
            end if;

            -- Restart tWTP counter on each write
            if do_write then
                tWTP_counter <= t_WTP - 2;
            elsif tWTP_counter > 0 then
                tWTP_counter <= tWTP_counter - 1;
            end if;

            -- The tRTP counter
            -- is two ticks and so is absorbed into the allow_read_o state
            -- We don't have time to block on next tick, but reads won't be
            -- generated any faster
            allow_read <= to_std_ulogic(tRCDRD_counter = 0);

            -- Trigger precharge when allowed
            if do_precharge then
                tRP_counter <= t_RP - 3;
                active_o <= '0';
                allow_write <= '0';
                allow_read <= '0';
                allow_precharge_o <= '1';
                state <= BANK_PRECHARGE;
            else
                allow_precharge_o <= to_std_ulogic(
                    tRAS_counter = 0 and tWTP_counter = 0) and
                    not do_read and not do_write;
            end if;
        end;

        procedure do_bank_precharge is
        begin
            if tRP_counter > 0 then
                tRP_counter <= tRP_counter - 1;
            else
                state <= BANK_IDLE;
            end if;
        end;

    begin
        if rising_edge(clk_i) then
            case state is
                when BANK_IDLE =>
                    do_bank_idle;
                when BANK_REFRESH =>
                    do_bank_refresh;
                when BANK_ACTIVE =>
                    do_bank_active;
                when BANK_PRECHARGE =>
                    do_bank_precharge;
            end case;
        end if;
    end process;

    old_o <= age(OLD_BANK_BITS);

    allow_refresh_o <= to_std_ulogic(state = BANK_IDLE);
    allow_activate_o <= to_std_ulogic(state = BANK_IDLE);
    allow_read_o <= allow_read;
    allow_write_o <= allow_write;
end;
