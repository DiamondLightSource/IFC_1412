-- Bank administration

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_timing_defs.all;
use work.gddr6_ctrl_core_defs.all;

entity gddr6_ctrl_banks is
    port (
        clk_i : in std_ulogic;

        request_i : in banks_request_t;
        request_accept_o : out std_ulogic := '0';

        admin_i : in banks_admin_t;
        admin_accept_o : out std_ulogic := '0';

        status_o : out banks_status_t
    );
end;

architecture arch of gddr6_ctrl_banks is
    -- Bank status
    signal write_active : std_ulogic := '0';
    signal read_active : std_ulogic := '0';
    signal allow_activate : std_ulogic_vector(0 to 15);
    signal allow_read : std_ulogic_vector(0 to 15);
    signal allow_write : std_ulogic_vector(0 to 15);
    signal allow_precharge : std_ulogic_vector(0 to 15);
    signal allow_refresh : std_ulogic_vector(0 to 15);
    signal allow_precharge_all : std_ulogic;
    signal allow_refresh_all : std_ulogic;
    signal active : std_ulogic_vector(0 to 15);
    signal row : unsigned_array(0 to 15)(13 downto 0);
    signal age : unsigned_array(0 to 15)(7 downto 0);

    -- Interface to bank
    signal request_bank : natural range 0 to 15;
    signal request_read : std_ulogic;
    signal request_write : std_ulogic;
    signal request_activate : std_ulogic;
    signal request_precharge : std_ulogic;
    signal request_refresh : std_ulogic;
    signal accept_read : std_ulogic;
    signal accept_write : std_ulogic;
    signal accept_activate : std_ulogic;
    signal accept_precharge : std_ulogic;
    signal accept_refresh : std_ulogic;

    function get_admin_banks(admin_i : banks_admin_t) return std_ulogic_vector
    is
        variable admin_bank : natural range 0 to 15;
        variable result : std_ulogic_vector(0 to 15) := (others => '0');
    begin
        admin_bank := to_integer(admin_i.bank);
        if admin_i.all_banks then
            result := (others => '1');
        elsif admin_i.command = CMD_REF then
            -- Special treatment for refresh
            result(admin_bank) := '1';
            result(admin_bank + 8 mod 16) := '1';
        else
            result(admin_bank) := '1';
        end if;
        return result;
    end;
    signal admin_banks : std_ulogic_vector(0 to 15);

    -- Timers for global bank state
    -- tRFCab: time for refresh of all banks to complete
    signal tRFCab_counter : natural range 0 to t_RFCab - 2 := 0;
    -- tRTW: minimum time from read to write commands
    signal tRTW_counter : natural range 0 to t_RTW - 2 := 0;
    -- tRTW: minimum time from read to write commands
    signal tWTR_counter : natural range 0 to t_WTR_time - 2 := 0;
    -- tRRD: ensure extra tick after ACT for following ACT or REF command
    signal tRRD_delay : std_ulogic := '0';
    -- tRREFD: delay from REF to REF or ACT on different bank
    signal tRREFD_counter : natural range 0 to t_RREFD - 2 := 0;
    signal refresh_busy : std_ulogic := '0';

    -- Holds all banks in refresh during REFab command
    signal refresh_all : std_ulogic := '0';

begin
    -- Decode incoming request
    request_bank <= to_integer(request_i.bank);
    request_read <=
        request_i.valid and to_std_ulogic(request_i.direction = DIR_READ) and
        not write_active;
    request_write <=
        request_i.valid and to_std_ulogic(request_i.direction = DIR_WRITE) and
        not read_active;

    -- Decode incoming admin
    request_activate <=
        admin_i.valid and to_std_ulogic(admin_i.command = CMD_ACT) and
        not tRRD_delay;
    request_precharge <=
        admin_i.valid and to_std_ulogic(admin_i.command = CMD_PRE) and
        (not admin_i.all_banks or allow_precharge_all);
    request_refresh <=
        admin_i.valid and to_std_ulogic(admin_i.command = CMD_REF) and
        (not admin_i.all_banks or allow_refresh_all) and not tRRD_delay;
    admin_banks <= get_admin_banks(admin_i);

    -- Instantiate the 16 banks
    gen_banks : for bank in 0 to 15 generate
        signal is_request_bank : std_ulogic;
        signal is_admin_bank : std_ulogic;
    begin
        is_request_bank <= to_std_ulogic(request_bank = bank);
        is_admin_bank <= admin_banks(bank);

        bank_inst : entity work.gddr6_ctrl_bank port map (
            clk_i => clk_i,

            active_o => active(bank),
            row_o => row(bank),
            age_o => age(bank),

            allow_activate_o => allow_activate(bank),
            allow_read_o => allow_read(bank),
            allow_write_o => allow_write(bank),
            allow_precharge_o => allow_precharge(bank),
            allow_refresh_o => allow_refresh(bank),

            request_read_i => request_read and is_request_bank,
            request_write_i => request_write and is_request_bank,
            request_activate_i => request_activate and is_admin_bank,
            request_precharge_i => request_precharge and is_admin_bank,
            request_refresh_i => request_refresh and is_admin_bank,

            auto_precharge_i => request_i.auto_precharge,
            row_i => admin_i.row,
            refresh_all_i => refresh_all
        );
    end generate;

    allow_precharge_all <= vector_and(allow_precharge);
    allow_refresh_all <= vector_and(allow_refresh);

    accept_read <= request_read and allow_read(request_bank);
    accept_write <= request_write and allow_write(request_bank);
    request_accept_o <= accept_read or accept_write;

    accept_activate <=
        request_activate and vector_and(not admin_banks or allow_activate);
    accept_precharge <=
        request_precharge and vector_and(not admin_banks or allow_precharge) and
        (not admin_i.all_banks or vector_and(allow_precharge));
    accept_refresh <=
        request_refresh and vector_and(not admin_banks or allow_refresh) and
        (not admin_i.all_banks or vector_and(allow_refresh));
    admin_accept_o <= accept_activate or accept_precharge or accept_refresh;

    process (clk_i) begin
        if rising_edge(clk_i) then
--             request_accept_o <= accept_read or accept_write;
--             admin_accept_o <=
--                 accept_activate or accept_precharge or accept_refresh;

            tRRD_delay <= accept_activate;

            -- Ensure read not accepted until t_WTR_time after write
            if accept_write then
                tWTR_counter <= t_WTR_time - 2;
                write_active <= '1';
            elsif tWTR_counter > 0 then
                tWTR_counter <= tWTR_counter - 1;
            else
                write_active <= '0';
            end if;

            -- Ensure write not accepted until t_RTW after read
            if accept_read then
                tRTW_counter <= t_RTW - 2;
                read_active <= '1';
            elsif tRTW_counter > 0 then
                tRTW_counter <= tRTW_counter - 1;
            else
                read_active <= '0';
            end if;

            -- During REFab processing we must block all processing
            if tRFCab_counter > 0 then
                tRFCab_counter <= tRFCab_counter - 1;
            elsif accept_refresh and admin_i.all_banks then
                tRFCab_counter <= t_RFCab - 2;
                refresh_all <= '1';
            else
                refresh_all <= '0';
            end if;

            -- Enforce tRREFD
            if tRREFD_counter > 0 then
                tRREFD_counter <= tRREFD_counter - 1;
            elsif accept_refresh then
                tRREFD_counter <= t_RREFD - 2;
                refresh_busy <= '1';
            else
                refresh_busy <= '0';
            end if;
        end if;
    end process;

    status_o <= (
        write_active => write_active,
        read_active => read_active,

--         allow_activate => allow_activate,
--         allow_read => allow_read,
--         allow_write => allow_write,
--         allow_precharge => allow_precharge,
--         allow_refresh => allow_refresh,
--         allow_precharge_all => allow_precharge_all,
--         allow_refresh_all => allow_refresh_all,

        active => active,
        row => row,
        age => age
    );
end;
