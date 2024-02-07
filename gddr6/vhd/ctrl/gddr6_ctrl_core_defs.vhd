-- Definitions for core

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gddr6_ctrl_commands.all;

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
    type sg_direction_t is (DIRECTION_READ, DIRECTION_WRITE);

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
end;
