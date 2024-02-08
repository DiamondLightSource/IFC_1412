-- Control and state of a single bank

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_timing_defs.all;
use work.gddr6_ctrl_core_defs.all;

entity gddr6_ctrl_bank is
    port (
        clk_i : in std_ulogic;

        -- Current state
        active_o : out std_ulogic := '0';   -- Set if activated
        row_o : out unsigned(13 downto 0);  -- Selected row when activated

        -- Permissions, driven by state and timers
        allow_activate_o : out std_ulogic := '1';
        allow_refresh_o : out std_ulogic := '1';
        allow_read_o : out std_ulogic := '0';
        allow_write_o : out std_ulogic := '0';
        allow_precharge_o : out std_ulogic := '1';

        -- Requested action on this bank if command_valid_i set
        command_i : in bank_command_t;
        command_valid_i : in std_ulogic;
        -- Only asserted with CMD_RD or CMD_WR to trigger auto precharge
        auto_precharge_i : in std_ulogic;
        -- Row to set for CMD_ACT
        row_i : in unsigned(13 downto 0)
    );
end;

architecture arch of gddr6_ctrl_bank is
    type row_state_t is (BANK_IDLE, BANK_REFRESH, BANK_ACTIVE, BANK_PRECHARGE);
    signal state : row_state_t := BANK_IDLE;

    signal auto_precharge : std_ulogic := '0';

    -- Counters for delays longer than 2 ticks
    --
    -- ACT to RD
    signal tRCDRD_counter : natural range 0 to t_RCDRD - 2 := 0;
    -- ACT to PRE
    signal tRAS_counter : natural range 0 to t_RAS - 2 := 0;
    -- WxM to PRE
    signal tWTP_counter : natural range 0 to t_WTP - 2 := 0;
    -- PRE to ACT
    signal tRP_counter : natural range 0 to t_RP - 2 := 0;
    -- REF to ACT
    signal tRFCpb_counter : natural range 0 to t_RFCpb - 2 := 0;

begin
    process (clk_i)
        procedure do_bank_idle is
        begin
            if command_valid_i = '1' and command_i = CMD_REF then
                tRFCpb_counter <= t_RFCpb - 2;
                allow_precharge_o <= '0';
                state <= BANK_REFRESH;
            elsif command_valid_i = '1' and command_i = CMD_ACT then
                tRCDRD_counter <= t_RCDRD - 2;
                tRAS_counter <= t_RAS - 2;
                tWTP_counter <= 0;
                auto_precharge <= '0';
                row_o <= row_i;
                active_o <= '1';
                allow_write_o <= '1';
                allow_precharge_o <= '0';
                state <= BANK_ACTIVE;
            end if;
        end;

        procedure do_bank_refresh is
        begin
            if tRFCpb_counter > 0 then
                tRFCpb_counter <= tRFCpb_counter - 1;
            else
                allow_precharge_o <= '1';
                state <= BANK_IDLE;
            end if;
        end;

        -- Process ACTIVE state: enable read/write/precharge and support auto-
        -- precharge.  Transition to PRECHARGE when requested
        procedure do_bank_active is
            variable do_write : std_ulogic;
            variable do_read : std_ulogic;
            variable do_precharge : std_ulogic;

        begin
            -- Decode the command requests
            do_write := allow_write_o and
                command_valid_i and to_std_ulogic(command_i = CMD_WR);
            do_read := allow_read_o and
                command_valid_i and to_std_ulogic(command_i = CMD_RD);
            do_precharge := allow_precharge_o and
                command_valid_i and to_std_ulogic(command_i = CMD_PRE);


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
            allow_write_o <= not auto_precharge;

            -- The tRTP counter
            -- is two ticks and so is absorbed into the allow_read_o state
            -- We don't have time to block on next tick, but reads won't be
            -- generated any faster
            allow_read_o <=
                not auto_precharge and to_std_ulogic(tRCDRD_counter = 0);

            -- Register precharge if requested on read or write.  This will
            -- block subsequent operations and automatically deactive the bank
            if auto_precharge_i and (do_read or do_write) then
                auto_precharge <= '1';
                active_o <= '0';
            end if;

            -- Trigger precharge when allowed
            if do_precharge or (allow_precharge_o and auto_precharge) then
                tRP_counter <= t_RP - 2;
                active_o <= '0';
                allow_write_o <= '0';
                allow_read_o <= '0';
                allow_precharge_o <= '1';
                state <= BANK_PRECHARGE;
            else
                allow_precharge_o <= to_std_ulogic(
                    tRAS_counter = 0 and tWTP_counter = 0) and
                    not do_read;
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

            -- Sanity checks during simulation
            --
            -- synthesis translate_off
            if command_valid_i then
                case command_i is
                    when CMD_ACT =>
                        assert allow_activate_o report "Invalid ACT"
                            severity failure;
                    when CMD_WR =>
                        assert allow_write_o report "Invalid WR"
                            severity failure;
                    when CMD_RD =>
                        assert allow_read_o report "Invalid RD"
                            severity failure;
                    when CMD_PRE =>
                        assert allow_precharge_o report "Invalid PRE"
                            severity failure;
                    when CMD_REF =>
                        assert allow_refresh_o report "Invalid REF"
                            severity failure;
                end case;
            end if;
            -- synthesis translate_on
        end if;
    end process;

    allow_refresh_o <= to_std_ulogic(state = BANK_IDLE);
    allow_activate_o <= to_std_ulogic(state = BANK_IDLE);
end;
