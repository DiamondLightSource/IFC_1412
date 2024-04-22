-- Bank administration

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_timing_defs.all;
use work.gddr6_ctrl_defs.all;

entity gddr6_ctrl_banks is
    port (
        clk_i : in std_ulogic;

        -- Request to open a bank
        bank_open_i : in bank_open_t;
        bank_open_ok_o : out std_ulogic;

        -- Request to perform read/write command
        out_request_i : in out_request_t;
        out_request_ok_o : out std_ulogic;
        out_request_extra_i : in std_ulogic;

        -- Request to execute admin command
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
    signal active : std_ulogic_vector(0 to 15);
    signal row : unsigned_array(0 to 15)(13 downto 0);
    signal young : std_ulogic_vector(0 to 15);
    signal old : std_ulogic_vector(0 to 15);

    -- Interface to bank
    signal open_bank : natural range 0 to 15;
    signal request_bank : natural range 0 to 15;
    signal admin_bank : natural range 0 to 15;
    signal request_read : std_ulogic;
    signal request_write : std_ulogic;
    signal request_activate : std_ulogic;
    signal request_precharge : std_ulogic;
    signal request_refresh : std_ulogic;
    signal request_precharge_banks : std_ulogic_vector(0 to 15);
    signal request_refresh_banks : std_ulogic_vector(0 to 15);
    signal accept_read : std_ulogic;
    signal accept_write : std_ulogic;
    signal accept_activate : std_ulogic;
    signal accept_precharge : std_ulogic;
    signal accept_refresh : std_ulogic;


    function read_write_request(
        direction : direction_t; request : out_request_t;
        other_active : std_ulogic; tCCD : std_ulogic) return std_ulogic is
    begin
        return
            request.valid and
            to_std_ulogic(request.direction = direction) and
            not other_active and not tCCD;
    end;

    -- Checks if the incoming request is for the specified command
    function admin_request(
        command : admin_command_t;
        admin : banks_admin_t) return std_ulogic is
    begin
        return admin.valid and to_std_ulogic(admin.command = command);
    end;

    -- Returns array of banks associated with incoming request
    function admin_request_banks(
        command : admin_command_t;
        admin : banks_admin_t) return std_ulogic_vector
    is
        variable admin_bank : natural range 0 to 15;
        variable result : std_ulogic_vector(0 to 15) := (others => '0');
    begin
        admin_bank := to_integer(admin.bank);
        if admin_request(command, admin) then
            if admin.all_banks then
                result := (others => '1');
            elsif command = CMD_REF then
                -- Special treatment for refresh which treats banks in pairs
                result(admin_bank) := '1';
                result(admin_bank + 8 mod 16) := '1';
            else
                result(admin_bank) := '1';
            end if;
        end if;
        return result;
    end;

    -- tCCD: two ticks between successive read or write commands
    signal tCCD_delay : std_ulogic := '0';
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

    -- Flags used to avoid precharging a bank while it has been accepted for
    -- opening and before it has been read or written.
    signal precharge_guard : std_ulogic_vector(0 to 15) := (others => '0');
    -- Copy of precharge request used as part of open guard
    signal precharge_active : std_ulogic_vector(0 to 15) := (others => '0');

    -- Block admin commands during read or write commands.  Admin commands are
    -- requested one tick later than the corresponding read/write commands, so
    -- we record the fact that read/write is busy here to block admin commands.
    signal block_admin : std_ulogic := '0';
    signal allow_admin : std_ulogic;

begin
    -- Instantiate the 16 banks
    gen_banks : for bank in 0 to 15 generate
        signal is_request_bank : std_ulogic;
        -- Register all requests to rescue timing
        signal request_activate_bank : std_ulogic;
        signal request_refresh_bank : std_ulogic;
        signal request_read_bank : std_ulogic;
        signal request_write_bank : std_ulogic;
        signal request_precharge_bank : std_ulogic;
        signal row_bank : unsigned(13 downto 0);

    begin
        is_request_bank <= to_std_ulogic(request_bank = bank);
        bank_inst : entity work.gddr6_ctrl_bank port map (
            clk_i => clk_i,

            active_o => active(bank),
            row_o => row(bank),
            young_o => young(bank),
            old_o => old(bank),

            allow_activate_o => allow_activate(bank),
            allow_read_o => allow_read(bank),
            allow_write_o => allow_write(bank),
            allow_precharge_o => allow_precharge(bank),
            allow_refresh_o => allow_refresh(bank),

            request_read_i => request_read_bank,
            request_write_i => request_write_bank,
            request_activate_i => request_activate_bank,
            request_precharge_i => request_precharge_bank,
            request_refresh_i => request_refresh_bank,

            row_i => row_bank,
            refresh_all_i => refresh_all
        );

        process (clk_i) begin
            if rising_edge(clk_i) then
                request_read_bank <= accept_read and is_request_bank;
                request_write_bank <= accept_write and is_request_bank;
                request_activate_bank <=
                    accept_activate and to_std_ulogic(bank = admin_bank);
                request_precharge_bank <=
                    accept_precharge and request_precharge_banks(bank);
                request_refresh_bank <=
                    accept_refresh and request_refresh_banks(bank);
                row_bank <= admin_i.row;
            end if;
        end process;
    end generate;


    -- Integer versions of the three banks
    open_bank <= to_integer(bank_open_i.bank);
    request_bank <= to_integer(out_request_i.bank);
    admin_bank <= to_integer(admin_i.bank);

    -- Bank open request: need to ensure that the requested bank is open on
    -- the correct row.  We also need to interact correctly with precharge: to
    -- ensure that refresh can take priority precharge needs to block opening
    -- the bank here, and we also need to ensure that once the bank has been
    -- accepted that precharge is blocked on this bank until the corresponding
    -- read/write request has completed.
    bank_open_ok_o <=
        bank_open_i.valid and active(open_bank) and
        to_std_ulogic(row(open_bank) = bank_open_i.row) and
        -- Block if there is any admin activity on this bank, specifically
        -- precharge.  Because of the clock skew between read/write and admin
        -- we also need to check against a registered copy of this request.
        not (admin_i.valid and not admin_accept_o and
            to_std_ulogic(open_bank = admin_bank)) and
        not precharge_active(open_bank) and
        -- Don't accept if a read/write request is pending, this blocks
        -- overlapping open and out.
        (not out_request_i.valid or out_request_ok_o);

    -- Decode incoming read/write request
    request_read <=
        read_write_request(DIR_READ, out_request_i, write_active, tCCD_delay);
    request_write <=
        read_write_request(DIR_WRITE, out_request_i, read_active, tCCD_delay);

    -- Activate is the simplest admin request as this only affects a single bank
    -- and doesn't need any special interlocking
    allow_admin <=
        not block_admin and not refresh_busy and not tRRD_delay
        and not admin_accept_o;
    request_activate <= admin_request(CMD_ACT, admin_i) and allow_admin;
    -- Precharge is either for a single bank or all banks
    request_precharge <= admin_request(CMD_PRE, admin_i) and allow_admin;
    request_precharge_banks <= admin_request_banks(CMD_PRE, admin_i);
    -- Refresh is either for a pair of banks or all banks
    request_refresh <= admin_request(CMD_REF, admin_i) and allow_admin;
    request_refresh_banks <= admin_request_banks(CMD_REF, admin_i);

    accept_read <= request_read and allow_read(request_bank);
    accept_write <= request_write and allow_write(request_bank);
    out_request_ok_o <= accept_read or accept_write;

    accept_activate <= request_activate and allow_activate(admin_bank);
    accept_precharge <=
        request_precharge and
        vector_and(not request_precharge_banks or
            (allow_precharge and not precharge_guard));
    accept_refresh <=
        request_refresh and
        vector_and(not request_refresh_banks or allow_refresh);

    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Ensure a one tick delay between successive read or write commands
            tCCD_delay <= accept_read or accept_write;
            -- One tick delay after activate
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

            -- Maintain the precharge guard: set bit when open accepted, clear
            -- bit when read or write accepted and not overlapping with open.
            for bank in 0 to 15 loop
                if bank = open_bank and bank_open_ok_o = '1' then
                    precharge_guard(bank) <= '1';
                elsif bank = request_bank and out_request_ok_o = '1' then
                    precharge_guard(bank) <= '0';
                end if;
            end loop;
            -- This is a copy of request_precharge_banks used to allow open to
            -- be guarded
            precharge_active <= request_precharge_banks;

            -- Block admin commands where necessary
            block_admin <= out_request_ok_o or out_request_extra_i;

            -- Register admin accept
            admin_accept_o <=
                accept_activate or accept_precharge or accept_refresh;
        end if;
    end process;

    status_o <= (
        write_active => write_active,
        read_active => read_active,
        active => active,
        row => row,
        young => young,
        old => old
    );
end;
