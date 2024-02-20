-- Command arbitration

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_commands.all;
use work.gddr6_ctrl_core_defs.all;

entity gddr6_ctrl_arb is
    port (
        clk_i : std_ulogic;

        -- Bank status information
        bank_active_i : in std_ulogic_vector(0 to 15);
        bank_row_i : in unsigned_array(0 to 15)(13 downto 0);
        bank_allow_read_i : in std_ulogic_vector(0 to 15);
        bank_allow_write_i : in std_ulogic_vector(0 to 15);
        -- This combinatorially assigned bit mask is used to identify the bank
        -- being checked and should be used to ensure the state doesn't change.
        bank_active_o : out std_ulogic_vector(0 to 15);

        -- Bank actions
        bank_action_read_o : out std_ulogic_vector(0 to 15)
            := (others => '0');
        bank_action_write_o : out std_ulogic_vector(0 to 15)
            := (others => '0');
        bank_action_auto_precharge_o : out std_ulogic_vector(0 to 15)
            := (others => '0');

        -- Memory direction
        direction_i : in direction_t;
        direction_idle_i : in std_ulogic;
        idle_priority_i : in direction_t;

        -- Outgoing bank activate request
        activate_bank_o : out unsigned(3 downto 0);
        activate_row_o : out unsigned(13 downto 0);
        activate_valid_o : out std_ulogic := '0';
        activate_ready_i : in std_ulogic;

        -- Write request with handshake
        write_request_i : in core_request_t;
        write_request_extra_i : in std_ulogic;
        write_request_ready_o : out std_ulogic := '0';

        -- Read request with handshake
        read_request_i : in core_request_t;
        read_request_ready_o : out std_ulogic := '0';

        -- Other command requests for bank management
        bank_command_i : in ca_command_t;
        bank_command_valid_i : in std_ulogic;
        bank_command_ready_o : out std_ulogic := '0';

        -- CA Commands out to PHY
        ca_command_o : out ca_command_t := SG_NOP
    );
end;

architecture arch of gddr6_ctrl_arb is
    type state_t is (
        ARB_IDLE,           -- Waiting for request
        ARB_ACCEPT,         -- Ordinary command accept
        ARB_ACTIVATE);      -- Request bank activation
    signal state : state_t := ARB_IDLE;

    signal source : direction_t := DIR_WRITE;
    signal bank_allow : std_ulogic_vector(0 to 15);
    signal request : core_request_t;
    signal request_extra : std_ulogic;
    signal bank_valid : std_ulogic;
    signal accept_request : std_ulogic;

begin
    -- The entire process of inspecting the incoming request against the
    -- selected bank needs to happen in a single tick
    process (all)
        variable request_bank : natural range 0 to 15;
    begin
        case source is
            when DIRECTION_READ =>
                request <= read_request_i;
                bank_allow <= bank_allow_read_i;
                request_extra <= '0';
            when DIRECTION_WRITE =>
                request <= write_request_i;
                bank_allow <= bank_allow_write_i;
                request_extra <= write_request_extra_i;
        end case;

        request_bank := to_integer(request.bank);
        bank_valid <=
            request.valid and bank_active_i(request_bank) and
            to_std_ulogic(bank_row_i(request_bank) = request.row);
        accept_request <= bank_valid and bank_allow(request_bank);
        compute_strobe(bank_active_o, request_bank, request.valid);
    end process;


    process (clk_i)
        -- Update which request we service depending on the current direction
        -- state.  When the memory has no preferred direction we have to make
        -- a suitable selection.
        impure function compute_source return direction_t is
        begin
            if direction_idle_i then
                case idle_priority_i is
                    when DIRECTION_READ =>
                        if read_request_i.valid then
                            return DIRECTION_READ;
                        else
                            return DIRECTION_WRITE;
                        end if;
                    when DIRECTION_WRITE =>
                        if write_request_i.valid then
                            return DIRECTION_WRITE;
                        else
                            return DIRECTION_READ;
                        end if;
                end case;
            else
                case direction_i is
                    when DIRECTION_READ =>
                        return DIRECTION_READ;
                    when DIRECTION_WRITE =>
                        return DIRECTION_WRITE;
                end case;
            end if;
        end;

        -- Normal default idle action: pass through bnak commands if requested,
        -- otherwise emit NOP
        procedure accept_bank_command is
        begin
            if bank_command_valid_i then
                ca_command_o <= bank_command_i;
            else
                ca_command_o <= SG_NOP;
            end if;
        end;

        procedure reset_actions is
        begin
            read_request_ready_o <= '0';
            write_request_ready_o <= '0';
            bank_action_read_o <= (others => '0');
            bank_action_write_o <= (others => '0');
            bank_action_auto_precharge_o <= (others => '0');
        end;

        -- Allow any bank command on entry to the IDLE state and update the
        -- accepted source.  This is triggered every time there is no command
        -- to accept.
        procedure enter_idle_state is
        begin
            bank_command_ready_o <= '1';
            read_request_ready_o <= '0';
            write_request_ready_o <= '0';
            bank_action_read_o <= (others => '0');
            bank_action_write_o <= (others => '0');
            bank_action_auto_precharge_o <= (others => '0');

            -- Update the active direction
            source <= compute_source;
            state <= ARB_IDLE;
        end;

        -- Enter accept state: accept and transmit the requested command
        procedure enter_accept_state is
        begin
            case source is
                when DIRECTION_READ =>
                    read_request_ready_o <= '1';
                    compute_strobe(
                        bank_action_read_o, to_integer(request.bank));
                when DIRECTION_WRITE =>
                    write_request_ready_o <= '1';
                    compute_strobe(
                        bank_action_write_o, to_integer(request.bank));
            end case;
            compute_strobe(
                bank_action_auto_precharge_o, to_integer(request.bank),
                request.precharge);

            bank_command_ready_o <= '0';
            state <= ARB_ACCEPT;
        end;

        -- The wait state is entered when we need to activate a new row
        procedure enter_activate_state is
        begin
            activate_bank_o <= request.bank;
            activate_row_o <= request.row;
            activate_valid_o <= '1';
            state <= ARB_ACTIVATE;
        end;

    begin
        if rising_edge(clk_i) then
            case state is
                when ARB_IDLE =>
                    -- In the idle state accept any bank command and monitor
                    -- the status of incoming requests.
                    if request.valid then
                        if bank_valid then
                            -- Once the bank is valid we know our request will
                            if accept_request then
                                enter_accept_state;
                            end if;
                        else
                            enter_activate_state;
                        end if;
                    else
                        -- In the absence of a valid request redo the source
                        -- computation to allow switching direciton
                        enter_idle_state;
                    end if;

                    -- In the idle state accept all bank commands
                    accept_bank_command;

                when ARB_ACCEPT =>
                    -- In this state a read/write request has been serviced.
                    -- Allow bank commands to be interleaved in this state
                    ca_command_o <= request.command;
                    if not request_extra then
                        enter_idle_state;
                    end if;
--                     reset_actions;

                when ARB_ACTIVATE =>
                    -- In this state we need to open a new bank.  Dwell in this
                    -- state until the activate request has been acknowleged.
                    if activate_ready_i then
                        activate_valid_o <= '0';
                        enter_idle_state;
                    end if;
                    accept_bank_command;
            end case;
        end if;
    end process;
end;
