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

        -- Currently activated banks
        active_banks_o : out std_ulogic_vector(15 downto 0);
        -- Current direction of operation
        direction_o : out sg_direction_t;
        direction_idle_o : out std_ulogic := '1';

        -- Read/write request.  If the requested bank is open with the requested
        -- row selected then match will be set, and ready will be reported when
        -- the bank is ready to take the requested command.  If the bank does
        -- not have the requested row open then match will be clear and ready
        -- will be reported straightaway.
        rw_request_i : in rw_bank_request_t;
        rw_request_matches_o : out std_ulogic;
        rw_request_ready_o : out std_ulogic := '0';

        -- Admin commands (ACT/PRE/REF)
        -- These are designed to be interleaved with read/write requests, and
        -- admin_ready_o will never be asserted at the same time as
        -- rw_request_ready_o
        admin_request_i : in bank_admin_t;
        admin_ready_o : out std_ulogic := '0'
    );
end;

architecture arch of gddr6_ctrl_banks is
    signal bank_active : std_ulogic_vector(0 to 15) := (others => '0');
    signal bank_rows : unsigned_array(0 to 15)(13 downto 0);

    signal allow_activate : std_ulogic_vector(0 to 15);
    signal allow_refresh : std_ulogic_vector(0 to 15);
    signal allow_read : std_ulogic_vector(0 to 15);
    signal allow_write : std_ulogic_vector(0 to 15);
    signal allow_precharge : std_ulogic_vector(0 to 15);

    signal bank_command : bank_command_t;
    signal command_valid : std_ulogic_vector(0 to 15) := (others => '0');
    signal auto_precharge : std_ulogic;
    signal activate_row : unsigned(13 downto 0);

    signal command_extra : std_ulogic := '0';
    signal refresh_all_active : std_ulogic := '0';

    -- Timers for global bank state
    -- tRFCab: time for refresh of all banks to complete
    signal tRFCab_counter : natural range 0 to t_RFCab - 2 := 0;
    -- tRTW: minimum time from read to write commands
    signal tRTW_counter : natural range 0 to t_RTW - 2 := 0;
    -- tRTW: minimum time from read to write commands
    signal tWTR_counter : natural range 0 to t_WTR_time - 2 := 0;

begin
    -- Instantiate the 16 banks
    gen_banks : for bank in 0 to 15 generate
        bank_inst : entity work.gddr6_ctrl_bank port map (
            clk_i => clk_i,

--             active_o => bank_active(bank),
--             row_o => bank_rows(bank),

            allow_activate_o => allow_activate(bank),
            allow_refresh_o => allow_refresh(bank),
            allow_read_o => allow_read(bank),
            allow_write_o => allow_write(bank),
            allow_precharge_o => allow_precharge(bank),

            command_i => bank_command,
            command_valid_i => command_valid(bank),
            auto_precharge_i => auto_precharge,
-- remove this!
            row_i => activate_row
        );
    end generate;
    active_banks_o <= bank_active;


    requests : process (clk_i)
        variable request_bank : natural range 0 to 15;
        variable bank_valid : std_ulogic;
        variable write_ok : std_ulogic;
        variable read_ok : std_ulogic;
        variable allow_request : std_ulogic;
        variable do_rw_request : std_ulogic;

        variable admin_bank : natural range 0 to 15;
        variable block_admin : std_ulogic;
        variable allow_admin : std_ulogic;
        variable do_admin_request : std_ulogic;

        variable start_RFCab : std_ulogic;
        variable start_WTR : std_ulogic;
        variable start_RTW : std_ulogic;

    begin
        if rising_edge(clk_i) then
            -- Compute read/write request
            --
            request_bank := to_integer(rw_request_i.bank);
            bank_valid :=
                rw_request_i.valid and bank_active(request_bank) and
                to_std_ulogic(bank_rows(request_bank) = rw_request_i.row);
            write_ok := direction_idle_o or
                to_std_ulogic(direction_o = DIRECTION_WRITE);
            read_ok := direction_idle_o or
                to_std_ulogic(direction_o = DIRECTION_READ);
            with rw_request_i.direction select
                allow_request :=
                    allow_read(request_bank) and read_ok   when DIRECTION_READ,
                    allow_write(request_bank) and write_ok when DIRECTION_WRITE;
            -- Process any read/write request when it can be completed
            do_rw_request := not command_extra and
                rw_request_i.valid and not rw_request_ready_o and
                (not bank_valid or allow_request);

            -- Compute admin request
            --
            admin_bank := to_integer(admin_request_i.bank);
            -- Block any admin commands on a pending read/write request on the
            -- same (or all) banks.
            block_admin := rw_request_i.valid and (
                to_std_ulogic(rw_request_i.bank = admin_request_i.bank) or
                admin_request_i.all_banks);
            if admin_request_i.all_banks then
                with admin_request_i.command select
                    allow_admin :=
                        vector_and(allow_precharge) when CMD_PRE,
                        vector_and(allow_refresh)   when CMD_REF,
                        '0' when others;
            else
                with admin_request_i.command select
                    allow_admin :=
                        allow_activate(admin_bank)  when CMD_ACT,
                        allow_precharge(admin_bank) when CMD_PRE,
                        allow_refresh(admin_bank)   when CMD_REF,
                        '0' when others;
            end if;
            do_admin_request :=
                admin_request_i.valid and not admin_ready_o and
                allow_admin and not block_admin and not refresh_all_active;


            if command_extra then
                -- If extra command processing requested simply skip processing
                -- until cleared
                command_extra <= rw_request_i.extra;
                command_valid <= (others => '0');
                rw_request_ready_o <= '0';
                admin_ready_o <= '0';
            elsif do_rw_request then
                with rw_request_i.direction select
                    bank_command <=
                        CMD_RD when DIRECTION_READ,
                        CMD_WR when DIRECTION_WRITE;
                compute_strobe(command_valid, request_bank, bank_valid);

                auto_precharge <= rw_request_i.precharge;
                command_extra <= rw_request_i.extra;
                rw_request_matches_o <= bank_valid;

                rw_request_ready_o <= '1';
                admin_ready_o <= '0';
            elsif do_admin_request then
                bank_command <= admin_request_i.command;
                activate_row <= admin_request_i.row;
                if admin_request_i.command = CMD_ACT then
                    bank_active(admin_bank) <= '1';
                    bank_rows(admin_bank) <= admin_request_i.row;
                elsif admin_request_i.command = CMD_PRE then
                    if admin_request_i.all_banks then
                        bank_active <= (others => '0');
                    else
                        bank_active(admin_bank) <= '0';
                    end if;
                end if;
                if admin_request_i.all_banks then
                    command_valid <= (others => '1');
                else
                    compute_strobe(command_valid, admin_bank);
                end if;
                admin_ready_o <= '1';
                rw_request_ready_o <= '0';
            else
                command_valid <= (others => '0');
                rw_request_ready_o <= '0';
                admin_ready_o <= '0';
            end if;


            -- Manage global state timer counters

            -- Trigger the timers when the appropriate command occurs
            start_RFCab := do_admin_request and not do_rw_request and
                to_std_ulogic(admin_request_i.command = CMD_REF) and
                admin_request_i.all_banks;
            start_WTR := do_rw_request and bank_valid and
                to_std_ulogic(rw_request_i.direction = DIRECTION_WRITE);
            start_RTW := do_rw_request and bank_valid and
                to_std_ulogic(rw_request_i.direction = DIRECTION_READ);


            -- During REFab processing we must block all processing
            if tRFCab_counter > 0 then
                tRFCab_counter <= tRFCab_counter - 1;
            elsif start_RFCab then
                tRFCab_counter <= t_RFCab - 2;
                refresh_all_active <= '1';
            else
                refresh_all_active <= '0';
            end if;

            -- Manage timing of read/write direction
            if start_WTR then
                tWTR_counter <= t_WTR_time - 2;
            elsif tWTR_counter > 0 then
                tWTR_counter <= tWTR_counter - 1;
            end if;

            if start_RTW then
                tRTW_counter <= t_RTW - 2;
            elsif tRTW_counter > 0 then
                tRTW_counter <= tRTW_counter - 1;
            end if;

            if start_WTR then
                direction_o <= DIRECTION_WRITE;
                direction_idle_o <= '0';
            elsif start_RTW then
                direction_o <= DIRECTION_READ;
                direction_idle_o <= '0';
            elsif tWTR_counter = 0 and tRTW_counter = 0 then
                direction_idle_o <= '1';
            end if;
        end if;
    end process;
end;
