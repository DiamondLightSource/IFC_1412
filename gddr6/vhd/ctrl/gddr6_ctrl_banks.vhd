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
        admin_i : in banks_admin_t;
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

    -- Timers for global bank state
    -- tRFCab: time for refresh of all banks to complete
    signal tRFCab_counter : natural range 0 to t_RFCab - 2 := 0;
    -- tRTW: minimum time from read to write commands
    signal tRTW_counter : natural range 0 to t_RTW - 2 := 0;
    -- tRTW: minimum time from read to write commands
    signal tWTR_counter : natural range 0 to t_WTR_time - 2 := 0;

    signal refresh_all : std_ulogic := '0';

begin
    -- Instantiate the 16 banks
    gen_banks : for bank in 0 to 15 generate
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

            request_activate_i => admin_i.activate(bank),
            request_read_i => request_i.read(bank),
            request_write_i => request_i.write(bank),
            request_precharge_i =>
                admin_i.precharge(bank) or
                (admin_i.precharge_all and allow_precharge_all),
            request_refresh_i =>
                admin_i.refresh(bank) or
                (admin_i.refresh_all and allow_refresh_all),

            read_active_i => read_active,
            write_active_i => write_active,

            auto_precharge_i => request_i.auto_precharge,
            row_i => admin_i.row,
            refresh_all_i => refresh_all
        );
    end generate;
    allow_precharge_all <= vector_and(allow_precharge);
    allow_refresh_all <= vector_and(allow_refresh);


    requests : process (clk_i)
        variable start_WTR : std_ulogic;
        variable start_RTW : std_ulogic;
        variable start_RFCab : std_ulogic;

    begin
        if rising_edge(clk_i) then
            -- Start all banks refresh when all banks are ready for refresh.
            start_RFCab := admin_i.refresh_all and allow_refresh_all;
            start_WTR := vector_or(request_i.write and status_o.allow_write);
            start_RTW := vector_or(request_i.read and status_o.allow_read);

            -- Manage timing of read/write direction
            if start_WTR then
                tWTR_counter <= t_WTR_time - 2;
                write_active <= '1';
            elsif tWTR_counter > 0 then
                tWTR_counter <= tWTR_counter - 1;
            else
                write_active <= '0';
            end if;

            if start_RTW then
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
            elsif start_RFCab then
                tRFCab_counter <= t_RFCab - 2;
                refresh_all <= '1';
            else
                refresh_all <= '0';
            end if;
        end if;
    end process;

    status_o <= (
        write_active => write_active,
        read_active => read_active,

        allow_activate => allow_activate,
        allow_read => allow_read,
        allow_write => allow_write,
        allow_precharge => allow_precharge,
        allow_refresh => allow_refresh,
        allow_precharge_all => allow_precharge_all,
        allow_refresh_all => allow_refresh_all,

        active => active,
        row => row,
        age => age
    );
end;
