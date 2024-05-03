-- Common CTRL definitions

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_command_defs.all;

package gddr6_ctrl_defs is
    -- Address decoding for the 25 bit burst address from the AXI interface,
    -- organised as | row | bank | column |.  This arrangement supports
    -- consecutive accesses to columns from a single open bank, and consecutive
    -- banks.
    subtype ROW_RANGE is natural range 24 downto 11;
    subtype BANK_RANGE is natural range 10 downto 7;
    subtype COLUMN_RANGE is natural range 6 downto 0;

    type direction_t is (DIR_READ, DIR_WRITE);
    type admin_command_t is (CMD_ACT, CMD_PRE, CMD_REF);

    -- This command request is presented to the core for dispatch to the phy.
    -- There is a lot going on here: first of all, streams are multiplexed
    -- together from read and writes, but command completion needs to be
    -- notified to the appropriate requester, so direction code is used to
    -- track the source of this command.
    type core_request_t is record
        -- Used to associate this request with its origin
        direction : direction_t;        -- Read/write marker
        write_advance : std_ulogic;     -- Only used for write commands
        -- The core content of this request: bank and row (required for admin
        -- validation) and the actual command to send
        bank : unsigned(3 downto 0);    -- Bank to read or write
        row : unsigned(13 downto 0);    -- Row to read or write
        command : ca_command_t;         -- CA command to send
        -- The following two flags worth together to ensure that write mask
        -- commands don't get detached from the write command
        next_extra : std_ulogic;        -- Write mask follows this command
        extra : std_ulogic;             -- This is a write mask command
        valid : std_ulogic;             -- Command valid
    end record;

    -- This event is generated when a core request is dispatched
    type request_completion_t is record
        direction : direction_t;        -- Direction of request
        advance : std_ulogic;           -- Controls advance of write address
        enables : std_ulogic_vector(0 to 3);    -- Channel enables for write
        valid : std_ulogic;             -- Set on completion
    end record;

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
        -- direction until the appropriate turnaround delay has passed
        write_active : std_ulogic;
        read_active : std_ulogic;
        active : std_ulogic_vector(0 to 15);
        -- The following are only valid for active banks
        row : unsigned_array(0 to 15)(13 downto 0);
        young : std_ulogic_vector(0 to 15);  -- < 2^N ticks
        old : std_ulogic_vector(0 to 15);    -- >= 2^M ticks
    end record;

    type refresh_request_t is record
        bank : unsigned(2 downto 0);
        all_banks : std_ulogic;
        priority : std_ulogic;
        valid : std_ulogic;
    end record;


    -- Constants for initialisers
    function IDLE_CORE_REQUEST(
        direction : direction_t := DIR_READ) return core_request_t;
    constant IDLE_COMPLETION : request_completion_t;
    constant IDLE_OPEN_REQUEST : bank_open_t;
    constant IDLE_OUT_REQUEST : out_request_t;
    constant IDLE_BANKS_ADMIN : banks_admin_t;
    constant IDLE_REFRESH_REQUEST : refresh_request_t;
end;

package body gddr6_ctrl_defs is
    function IDLE_CORE_REQUEST(
        direction : direction_t := DIR_READ) return core_request_t is
    begin
        return (
            direction => direction,
            write_advance => '0',
            bank => (others => '0'),
            row => (others => '0'),
            command => SG_NOP,
            next_extra => '0',
            extra => '0',
            valid => '0'
        );
    end;

    constant IDLE_COMPLETION : request_completion_t := (
        direction => DIR_READ,
        advance => '0',
        enables => "0000",
        valid => '0'
    );

    constant IDLE_OPEN_REQUEST : bank_open_t := (
        bank => (others => '0'),
        row => (others => '0'),
        valid => '0'
    );

    constant IDLE_OUT_REQUEST : out_request_t := (
        direction => DIR_READ,
        bank => (others => '0'),
        valid => '0'
    );

    constant IDLE_BANKS_ADMIN : banks_admin_t := (
        command => CMD_ACT,
        bank => (others => '0'),
        all_banks => '0',
        row => (others => '0'),
        valid => '0'
    );

    constant IDLE_REFRESH_REQUEST : refresh_request_t := (
        bank => (others => '0'),
        all_banks => '0',
        priority => '0',
        valid => '0'
    );
end;
