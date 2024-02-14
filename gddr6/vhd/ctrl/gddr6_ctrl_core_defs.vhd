-- Definitions for core

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_command_defs.all;

package gddr6_ctrl_core_defs is
    -- This command request is presented to the core for dispatch to the phy
    type core_request_t is record
        bank : unsigned(3 downto 0);    -- Bank to read or write
        row : unsigned(13 downto 0);    -- Row to read or write
        command : ca_command_t;         -- CA command to send
        precharge : std_ulogic;         -- Command sent with auto-precharge
        extra : std_ulogic;             -- Write mask follows this command
        valid : std_ulogic;             -- Command valid
    end record;

    -- This lookahead request can be presented to the core in time so that a
    -- following core request can be honoured immediately
    type core_lookahead_t is record
        bank : unsigned(3 downto 0);
        row : unsigned(13 downto 0);
        valid : std_ulogic;
    end record;

    -- This type will be separately qualified by an idle flag
    type sg_direction_t is (DIR_READ, DIR_WRITE);

    -- Request for read/write action on banks
    type banks_request_t is record
        read : std_ulogic_vector(0 to 15);
        write : std_ulogic_vector(0 to 15);
        auto_precharge : std_ulogic;
    end record;

    -- Request for admin command (ACT/PRE/REF/PREab/REFab)
    type banks_admin_t is record
        activate : std_ulogic_vector(0 to 15);
        precharge : std_ulogic_vector(0 to 15);
        refresh : std_ulogic_vector(0 to 15);
        precharge_all : std_ulogic;
        refresh_all : std_ulogic;
        -- Row for precharge operation
        row : unsigned(13 downto 0);
    end record;

    type banks_status_t is record
        -- At most one of these is set, and blocks activity in the opposite
        -- direction
        write_active : std_ulogic;
        read_active : std_ulogic;

        allow_activate : std_ulogic_vector(0 to 15);
        allow_read : std_ulogic_vector(0 to 15);
        allow_write : std_ulogic_vector(0 to 15);
        allow_precharge : std_ulogic_vector(0 to 15);
        allow_refresh : std_ulogic_vector(0 to 15);
        allow_precharge_all : std_ulogic;
        allow_refresh_all : std_ulogic;

        active : std_ulogic_vector(0 to 15);
        row : unsigned_array(0 to 15)(13 downto 0);
        age : unsigned_array(0 to 15)(7 downto 0);
    end record;


    -- Constants for initialisers
    constant IDLE_CORE_REQUEST : core_request_t;
    constant IDLE_CORE_LOOKAHEAD : core_lookahead_t;
    constant IDLE_BANKS_REQUEST : banks_request_t;
    constant IDLE_BANKS_ADMIN : banks_admin_t;
end;

package body gddr6_ctrl_core_defs is
    constant IDLE_CORE_REQUEST : core_request_t := (
        bank => (others => '0'),
        row => (others => '0'),
        command => SG_NOP,
        precharge => '0',
        extra => '0',
        valid => '0'
    );

    constant IDLE_CORE_LOOKAHEAD : core_lookahead_t := (
        bank => (others => '0'),
        row => (others => '0'),
        valid => '0'
    );

    constant IDLE_BANKS_REQUEST : banks_request_t := (
        read => (others => '0'),
        write => (others => '0'),
        auto_precharge => '0'
    );

    constant IDLE_BANKS_ADMIN : banks_admin_t := (
        activate => (others => '0'),
        precharge => (others => '0'),
        refresh => (others => '0'),
        precharge_all => '0',
        refresh_all => '0',
        row => (others => '0')
    );
end;
