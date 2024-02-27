-- Command flow for read/write commands

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_command_defs.all;
use work.gddr6_ctrl_core_defs.all;

entity gddr6_ctrl_request is
    port (
        clk_i : std_ulogic;

        -- Selects between read and write requests
        direction_i : in direction_t;
        -- If refresh is running out of time and cannot access a bank this
        -- request will stall progress
        refresh_stall_i : in std_ulogic;

        -- Write request with handshake and completion
        write_request_i : in core_request_t;
        write_request_ready_o : out std_ulogic := '0';
        write_request_sent_o : out std_ulogic := '0';

        -- Read request with handshake and completion
        read_request_i : in core_request_t;
        read_request_ready_o : out std_ulogic := '0';
        read_request_sent_o : out std_ulogic := '0';

        -- Check bank open and reserve
        bank_open_o : out bank_open_t;
        bank_open_ok_i : in std_ulogic;
        -- Request to open bank.  This is asserted while an open bank request
        -- is being rejected
        bank_open_request_o : out std_logic := '0';

        -- Bank read/write request
        out_request_o : out out_request_t;
        out_request_ok_i : in std_ulogic;

        -- CA Commands out to PHY
        command_o : out ca_command_t;
        command_valid_o : out std_ulogic := '0'
    );
end;

architecture arch of gddr6_ctrl_request is
    -- There are three stages of operation:
    --  1.  Incoming read and write requests are multiplexed according to the
    --      selected direction into in_request.  Care is taken to ensure that
    --      extra data is not separated.
    --  2.  The selected request is passed to bank_open_o to ensure that the
    --      selected bank is open on the correct row.  This is stored in
    --      request_bank.
    --  3.  The selected valid request then needs to wait for memory to become
    --      ready.  Typically this is just a wait for change of direction.
    --      The result is stored in request_out, which is available for output.
    --
    -- Requests flow through the following stages with checking as shown
    --
    --  (write_request_i, read_request_i)
    --      => in_request       selected by request_direction
    --      => bank_request     bank checked on bank_select_request
    --      => out_request      output ready checked on out_select_request
    --      => command_o

    signal request_direction : direction_t;
    signal direction_locked : std_ulogic := '0';

    -- Incoming request registered from selected source
    signal in_request : core_request_t := IDLE_CORE_REQUEST;
    signal in_advance : std_ulogic := '0';

    -- Bank validated command
    signal bank_select_request : core_request_t;
    signal bank_request : core_request_t := IDLE_CORE_REQUEST;
    signal bank_ok : std_ulogic := '0';
    signal bank_advance : std_ulogic := '0';

    -- Outgoing command
    signal out_select_request : core_request_t;
    signal out_request : core_request_t := IDLE_CORE_REQUEST;
    signal out_ok : std_ulogic := '0';
    signal out_advance : std_ulogic := '0';
    -- out_request.valid needs special treatment and some lookahead, so maintain
    -- these separately.  So next_out_valid replaces out_select_request, and
    -- out_valid replaces out_request.valid
    signal next_out_valid : std_ulogic;

    -- Used to inform the reader or writer that their request has been sent, and
    -- that data will follow at the appropriate time.
    signal request_sent : std_ulogic := '0';

begin
    -- Input flow control, acknowledge input from selected direction
    with request_direction select
        write_request_ready_o <= in_advance when DIR_WRITE, '0' when DIR_READ;
    with request_direction select
        read_request_ready_o <= '0' when DIR_WRITE, in_advance when DIR_READ;

    -- At each pipeline stage select from upstream source when advancing stage,
    -- otherwise select from current source
    bank_select_request <= in_request when bank_advance else bank_request;
    out_select_request <= bank_request when out_advance else out_request;

    -- Check for bank open request: ensure that requested bank is open on the
    -- requested row.  Bypass this check altogether for extra commands.
    bank_open_o <= (
        bank => bank_select_request.bank,
        row => bank_select_request.row,
        valid => bank_select_request.valid and not bank_select_request.extra
    );

    -- We can't just use out_select_request.valid as this needs to be qualified
    -- by the bank ok status
    next_out_valid <=
        bank_request.valid and bank_ok when out_advance
        else out_request.valid;
    -- Check for bank ready and ensure that the bank engine is kept in step with
    -- requested commands.
    out_request_o <= (
        direction => out_select_request.direction,
        bank => out_select_request.bank,
        auto_precharge => out_select_request.precharge,
        valid => next_out_valid and not out_ok and not out_select_request.extra,
        extra => out_select_request.extra
    );


    -- Unregistered (no lookahead) version of advance control:
    out_advance <= out_ok or not out_request.valid;
    bank_advance <= (bank_ok and out_advance) or not bank_request.valid;
    in_advance <= bank_advance or not in_request.valid;

    request_sent <= out_ok and out_request.valid and not out_request.extra;

    process (clk_i)
        variable lock_direction : std_ulogic;
    begin
        if rising_edge(clk_i) then
            -- Only change direction when current request has no extra data
            lock_direction :=
                to_std_ulogic(request_direction = DIR_WRITE) and
                write_request_i.valid and write_request_i.next_extra;
            -- Also, only change direction when advancing input to avoid missing
            -- a lock condition
            if not lock_direction and in_advance then
                request_direction <= direction_i;
            end if;

            -- Update input when possibe
            -- Input multiplexer
            if in_advance then
                if refresh_stall_i and not lock_direction then
                    in_request <= IDLE_CORE_REQUEST;
                else
                    with request_direction select
                        in_request <=
                            read_request_i when DIR_READ,
                            write_request_i when DIR_WRITE;
                end if;
            end if;

            -- Update bank when ok and not blocked on previous command
            bank_ok <=
                bank_select_request.extra or
                (bank_open_ok_i and bank_select_request.valid);
            if bank_advance then
                bank_request <= in_request;
            end if;
            bank_open_request_o <= not bank_ok and bank_request.valid;

            -- Compute output advance conditions
            out_ok <=
                out_select_request.extra or
                (out_request_ok_i and next_out_valid);
            if out_advance then
                out_request <= bank_request;
                -- Need to qualify out_request.valid: don't accept the transfer
                -- unless the bank was good.
                out_request.valid <= bank_request.valid and bank_ok;
            end if;

            -- Notify requester on completion of request
            case out_request.direction is
                when DIR_WRITE =>
                    write_request_sent_o <= request_sent;
                    read_request_sent_o <= '0';
                when DIR_READ =>
                    write_request_sent_o <= '0';
                    read_request_sent_o <= request_sent;
            end case;
        end if;
    end process;

    command_o <= out_request.command;
    command_valid_o <= out_ok and out_request.valid;
end;
