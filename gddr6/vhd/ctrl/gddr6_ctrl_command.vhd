-- Command dispatch and bank management

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_command_defs.all;
use work.gddr6_ctrl_core_defs.all;

entity gddr6_ctrl_command is
    port (
        clk_i : std_ulogic;

        -- Write request and report when sent
        write_request_i : in core_request_t;
        write_request_ready_o : out std_ulogic;
        write_request_sent_o : out std_ulogic;

        -- Read request and report when sent
        read_request_i : in core_request_t;
        read_request_ready_o : out std_ulogic;
        read_request_sent_o : out std_ulogic;

        -- Admin request
        admin_i : in banks_admin_t;
        admin_ready_o : out std_ulogic;

        -- Bypass channel for other commands
        bypass_command_i : in ca_command_t;
        bypass_valid_i : in std_ulogic;

        -- Request to pause read and writes
        refresh_stall_i : in std_ulogic;
        -- Direction selection
        direction_i : in direction_t;
        -- Request to open bank from read or write request
        bank_open_o : out bank_open_t;
        -- Bank status to guide open and refresh
        banks_status_o : out banks_status_t;

        -- CA Commands out to PHY
        ca_command_o : out ca_command_t := SG_NOP
    );
end;

architecture arch of gddr6_ctrl_command is
    signal bank_open : bank_open_t;
    signal bank_open_ok : std_ulogic;
    signal out_request : out_request_t;
    signal out_request_ok : std_ulogic;

    signal mux_request : core_request_t;
    signal mux_ready : std_ulogic;
    signal bank_open_request : std_ulogic;
    signal request_command : ca_command_t;
    signal request_command_valid : std_ulogic;

    signal admin_in : banks_admin_t := IDLE_BANKS_ADMIN;
    signal admin_ready : std_ulogic;
    signal admin_command : ca_command_t;
    signal admin_valid : std_ulogic := '0';

begin
    banks : entity work.gddr6_ctrl_banks port map (
        clk_i => clk_i,

        bank_open_i => bank_open,
        bank_open_ok_o => bank_open_ok,

        out_request_i => out_request,
        out_request_ok_o => out_request_ok,

        admin_i => admin_in,
        admin_accept_o => admin_ready,

        status_o => banks_status_o
    );

    request_mux : entity work.gddr6_ctrl_request_mux port map (
        clk_i => clk_i,

        direction_i => direction_i,
        stall_i => refresh_stall_i,

        write_request_i => write_request_i,
        write_ready_o => write_request_ready_o,

        read_request_i => read_request_i,
        read_ready_o => read_request_ready_o,

        out_request_o => mux_request,
        out_ready_i => mux_ready
    );

    request : entity work.gddr6_ctrl_request port map (
        clk_i => clk_i,

        mux_request_i => mux_request,
        mux_ready_o => mux_ready,

        write_request_sent_o => write_request_sent_o,
        read_request_sent_o => read_request_sent_o,

        bank_open_o => bank_open,
        bank_open_ok_i => bank_open_ok,
        bank_open_request_o => bank_open_request,

        out_request_o => out_request,
        out_request_ok_i => out_request_ok,

        command_o => request_command,
        command_valid_o => request_command_valid
    );

    bank_open_o <= (
        bank => bank_open.bank,
        row => bank_open.row,
        valid => bank_open_request
    );

    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Buffer incoming admin command
            if not admin_in.valid or admin_ready then
                admin_in <= admin_i;
            end if;

            -- Decode the admin command
            case admin_in.command is
                when CMD_ACT =>
                    admin_command <= SG_ACT(admin_in.bank, admin_in.row);
                when CMD_PRE =>
                    if admin_in.all_banks then
                        admin_command <= SG_PREab;
                    else
                        admin_command <= SG_PREpb(admin_in.bank);
                    end if;
                when CMD_REF =>
                    if admin_in.all_banks then
                        admin_command <= SG_REFab;
                    else
                        admin_command <= SG_REFp2b(admin_in.bank(2 downto 0));
                    end if;
            end case;
            admin_valid <= admin_ready;

            -- Send the requested command
            if request_command_valid then
                ca_command_o <= request_command;
            elsif admin_valid then
                ca_command_o <= admin_command;
            elsif bypass_valid_i then
                ca_command_o <= bypass_command_i;
            else
                ca_command_o <= SG_NOP;
            end if;
        end if;
    end process;
    admin_ready_o <= not admin_in.valid;
end;
