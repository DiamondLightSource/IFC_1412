-- Command flow for read/write commands

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_command_defs.all;
use work.gddr6_ctrl_core_defs.all;

entity gddr6_ctrl_command is
    port (
        clk_i : std_ulogic;

        -- Bank status and handshake required for validation and control
        banks_status_i : in banks_status_t;
        banks_request_o : out banks_request_t;

        -- Selects between read and write requests
        direction_i : in direction_t;

        -- Write request with handshake
        write_request_i : in core_request_t;
        write_request_ready_o : out std_ulogic;
        write_request_sent_o : out std_ulogic;

        -- Read request with handshake
        read_request_i : in core_request_t;
        read_request_ready_o : out std_ulogic;
        read_request_sent_o : out std_ulogic;

        -- Other admin commands, these flow through when available
        admin_command_i : in ca_command_t;
        admin_command_valid_i : in std_ulogic;
        admin_command_ready_o : out std_ulogic;

        -- Bank open request, generated when current command needs a new bank
        -- and row opened
        open_bank_valid_o : out std_ulogic := '0';
        open_bank_o : out unsigned(3 downto 0);
        open_bank_row_o : out unsigned(13 downto 0);

        -- CA Commands out to PHY
        ca_command_o : out ca_command_t := SG_NOP
    );
end;

architecture arch of gddr6_ctrl_command is
    signal request_direction : direction_t;
    signal direction_locked : std_ulogic := '0';

    -- Incoming request registered from selected source
    signal direction_in : direction_t;
    signal request_in : core_request_t := IDLE_CORE_REQUEST;
    signal request_in_ready : std_ulogic;

    -- Outgoing command
    signal direction_out : direction_t;
    signal request_out : core_request_t := IDLE_CORE_REQUEST;

    signal enable_advance : std_ulogic := '1';
    signal bank_ready : std_ulogic := '0';

    signal request_sent : std_ulogic := '0';

begin
    request_in_ready <= enable_advance or not request_in.valid;
    process (all) begin
        -- Flow control for input multiplexer
        case request_direction is
            when DIR_WRITE =>
                write_request_ready_o <= request_in_ready;
                read_request_ready_o <= '0';
            when DIR_READ =>
                write_request_ready_o <= '0';
                read_request_ready_o <= request_in_ready;
        end case;
    end process;

    requests : process (clk_i)
        variable lock_direction : std_ulogic;
        -- Multiplex between request_in or request out
        variable test_request : core_request_t;
        variable test_direction : direction_t;
        -- Intermediate calculations for request assessment
        variable test_bank : natural range 0 to 15;
        variable test_ready : std_ulogic;
        variable test_matches : std_ulogic;
        variable test_force : std_ulogic;
        variable test_new_request : std_ulogic;

    begin
        if rising_edge(clk_i) then
            -- Only change direction when current request has no extra data
            lock_direction :=
                to_std_ulogic(request_direction = DIR_WRITE) and
                write_request_i.valid and write_request_i.extra;
            -- Also, only change direction when advancing input to avoid missing
            -- a lock condition
            if not lock_direction and request_in_ready then
                request_direction <= direction_i;
            end if;

            -- Input multiplexer
            if request_in_ready then
                direction_in <= request_direction;
                with request_direction select
                    request_in <=
                        read_request_i when DIR_READ,
                        write_request_i when DIR_WRITE;
            end if;

            -- If data advance is blocked then we need to inspect the output
            -- register, otherwise for normal flow inspect the input as we have
            -- already committed to shipping the output
            if enable_advance then
                test_direction := direction_in;
                test_request := request_in;
            else
                test_direction := direction_out;
                test_request := request_out;
            end if;

            -- Check with bank whether ready to accept this request
            test_bank := to_integer(test_request.bank);
            with test_direction select
                test_ready :=
                    banks_status_i.allow_read(test_bank)  when DIR_READ,
                    banks_status_i.allow_write(test_bank) when DIR_WRITE;
            -- Check whether the requested bank is open on the correct row
            test_matches :=
                test_request.valid and banks_status_i.active(test_bank) and
                to_std_ulogic(
                    banks_status_i.row(test_bank) = test_request.row);

            -- If the current write has extra content following then force
            -- bypass of flow control for following commands.  This is used to
            -- keep write masks associated with their original command.
            test_force := request_out.extra and bank_ready;
            -- Recognise the start of a new request.
            test_new_request :=
                test_matches and test_ready and
                not request_sent and not test_force;

            -- Emit a command when we can or when forced
            bank_ready <= test_new_request or test_force;
            -- Advance data when emitting a command, or when no command seen,
            -- but not immediately after sending a command
            enable_advance <=
                test_new_request or test_force or not test_request.valid;
            -- Remember start of request to ensure we don't sent two requests
            -- on consecutive ticks
            request_sent <= test_new_request;

            -- Request open bank when request is valid but match fails
            open_bank_valid_o <= test_request.valid and not test_matches;
            open_bank_o <= test_request.bank;
            open_bank_row_o <= test_request.row;

            -- Register output
            if enable_advance then
                direction_out <= direction_in;
                request_out <= request_in;
            end if;

            -- Output generation
            if bank_ready then
                ca_command_o <= request_out.command;
            elsif admin_command_valid_i then
                ca_command_o <= admin_command_i;
            else
                ca_command_o <= SG_NOP;
            end if;

            -- Notify requester on completion of request
            case direction_out is
                when DIR_WRITE =>
                    write_request_sent_o <= request_sent;
                    read_request_sent_o <= '0';
                when DIR_READ =>
                    write_request_sent_o <= '0';
                    read_request_sent_o <= request_sent;
            end case;
        end if;
    end process;

    -- Pass through admin commands when we're not otherwise busy
    admin_command_ready_o <= not bank_ready;
end;
