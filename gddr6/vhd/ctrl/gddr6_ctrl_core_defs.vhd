-- Definitions for core

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_command_defs.all;

package gddr6_ctrl_core_defs is
    -- This command request is presented to the core for dispatch to the phy
    type core_request_t is record
        bank : unsigned(3 downto 0);
        row : unsigned(13 downto 0);
        command : ca_command_t;
        precharge : std_ulogic;
        valid : std_ulogic;
    end record;

    -- This lookahead request can be presented to the core in time so that a
    -- following core request can be honoured immediately
    type core_lookahead_t is record
        bank : unsigned(3 downto 0);
        row : unsigned(13 downto 0);
        valid : std_ulogic;
    end record;

    -- One of the following commands can be addressed to a bank
    type bank_command_t is (CMD_ACT, CMD_WR, CMD_RD, CMD_PRE, CMD_REF);

    -- This type will be separately qualified by an idle flag
    type sg_direction_t is (DIR_READ, DIR_WRITE);

    -- Simple read/write request from arbiter
    type rw_bank_request_t is record
        bank : unsigned(3 downto 0);
        row : unsigned(13 downto 0);
        direction : sg_direction_t;
        precharge : std_ulogic;
        extra : std_ulogic;
        valid : std_ulogic;
    end record;

    type bank_admin_t is record
        command : bank_command_t;
        bank : unsigned(3 downto 0);
        row : unsigned(13 downto 0);
        all_banks : std_ulogic;
        valid : std_ulogic;
    end record;




    -- Bank status information needed for generating read/write
    type bank_status_t is record
        active : std_ulogic_vector(0 to 15);            -- Set if bank active
        rows : unsigned_array(0 to 15)(13 downto 0);    -- Row open on bank
        -- Ready flags for bank actions
        read_ready : std_ulogic_vector(0 to 15);
        write_ready : std_ulogic_vector(0 to 15);
        activate_ready : std_ulogic_vector(0 to 15);
        precharge_ready : std_ulogic_vector(0 to 15);
        refresh_ready : std_ulogic_vector(0 to 15);
    end record;

    -- Bank control and response during read/write
    type bank_rw_response_t is record
        reserve : std_ulogic;                   -- Reserves bank for r/w action
        reserve_bank : unsigned(3 downto 0);    -- Identifies reserved bank
        direction : sg_direction_t;             -- Direction of action
        action : std_ulogic;                    -- Strobed when action sent
    end record;


    -- Constants for initialisers
    constant invalid_core_request : core_request_t;
    constant invalid_core_lookahead : core_lookahead_t;
    constant invalid_bank_request : rw_bank_request_t;
    constant invalid_admin_request : bank_admin_t;
end;

package body gddr6_ctrl_core_defs is
    constant invalid_core_request : core_request_t := (
        bank => (others => '0'),
        row => (others => '0'),
        command => SG_NOP,
        precharge => '0',
        valid => '0'
    );

    constant invalid_core_lookahead : core_lookahead_t := (
        bank => (others => '0'),
        row => (others => '0'),
        valid => '0'
    );

    constant invalid_bank_request : rw_bank_request_t := (
        bank => (others => '0'),
        row => (others => '0'),
        direction => DIR_READ,
        precharge => '0',
        extra => '0',
        valid => '0'
    );

    constant invalid_admin_request : bank_admin_t := (
        command => CMD_ACT,
        bank => (others => '0'),
        row => (others => '0'),
        all_banks => '0',
        valid => '0'
    );
end;
