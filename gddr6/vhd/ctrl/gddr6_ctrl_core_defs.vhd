-- Definitions for core

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_command_defs.all;

package gddr6_ctrl_core_defs is
    type direction_t is (DIR_READ, DIR_WRITE);

    -- This command request is presented to the core for dispatch to the phy
    type core_request_t is record
        direction : direction_t;        -- Read/write marker
        bank : unsigned(3 downto 0);    -- Bank to read or write
        row : unsigned(13 downto 0);    -- Row to read or write
        command : ca_command_t;         -- CA command to send
        precharge : std_ulogic;         -- Command sent with auto-precharge
        valid : std_ulogic;             -- Command valid
        -- The following two flags worth together to ensure that write mask
        -- commands don't get detached from the write command
        next_extra : std_ulogic;        -- Write mask follows this command
        extra : std_ulogic;             -- This is a write mask command
    end record;

    -- This lookahead request can be presented to the core in time so that a
    -- following core request can be honoured immediately
    type core_lookahead_t is record
        bank : unsigned(3 downto 0);
        row : unsigned(13 downto 0);
        valid : std_ulogic;
    end record;

    type admin_command_t is (CMD_ACT, CMD_PRE, CMD_REF);

    -- Request to check bank and row status
    type bank_open_t is record
        bank : unsigned(3 downto 0);
        row : unsigned(13 downto 0);
        valid : std_ulogic;
    end record;

    -- Request for read/write action on selected bank
    type out_request_t is record
        direction : direction_t;
        bank : unsigned(3 downto 0);
        auto_precharge : std_ulogic;
        extra : std_ulogic;
        valid : std_ulogic;
    end record;


    -- Request for admin command (ACT/PRE/REF/PREab/REFab)
    type banks_admin_t is record
        command : admin_command_t;
        bank : unsigned(3 downto 0);
        all_banks : std_ulogic;
        row : unsigned(13 downto 0);
        valid : std_ulogic;
    end record;

    type banks_status_t is record
        -- At most one of these is set, and blocks activity in the opposite
        -- direction
        write_active : std_ulogic;
        read_active : std_ulogic;

--         allow_activate : std_ulogic_vector(0 to 15);
--         allow_read : std_ulogic_vector(0 to 15);
--         allow_write : std_ulogic_vector(0 to 15);
--         allow_precharge : std_ulogic_vector(0 to 15);
--         allow_refresh : std_ulogic_vector(0 to 15);
--         allow_precharge_all : std_ulogic;
--         allow_refresh_all : std_ulogic;

        active : std_ulogic_vector(0 to 15);
        row : unsigned_array(0 to 15)(13 downto 0);
        age : unsigned_array(0 to 15)(7 downto 0);
    end record;


    -- Constants for initialisers
    function IDLE_CORE_REQUEST(
        direction : direction_t := DIR_READ) return core_request_t;
    constant IDLE_CORE_LOOKAHEAD : core_lookahead_t;
    constant IDLE_OUT_REQUEST : out_request_t;
    constant IDLE_BANKS_ADMIN : banks_admin_t;
end;

package body gddr6_ctrl_core_defs is
    function IDLE_CORE_REQUEST(
        direction : direction_t := DIR_READ) return core_request_t is
    begin
        return (
            direction => direction,
            bank => (others => '0'),
            row => (others => '0'),
            command => SG_NOP,
            precharge => '0',
            valid => '0',
            next_extra => '0',
            extra => '0'
        );
    end;

    constant IDLE_CORE_LOOKAHEAD : core_lookahead_t := (
        bank => (others => '0'),
        row => (others => '0'),
        valid => '0'
    );

    constant IDLE_OUT_REQUEST : out_request_t := (
        direction => DIR_READ,
        bank => (others => '0'),
        auto_precharge => '0',
        extra => '0',
        valid => '0'
    );

    constant IDLE_BANKS_ADMIN : banks_admin_t := (
        command => CMD_ACT,
        bank => (others => '0'),
        all_banks => '0',
        row => (others => '0'),
        valid => '0'
    );
end;
