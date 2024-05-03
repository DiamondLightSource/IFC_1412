-- Controller tuning and alignment parameters

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package gddr6_ctrl_tuning_defs is
    -- Bank aging parameters
    -- A bank that has been accessed less than 2^YOUNG_BANK_BITS is "young" and
    -- should be treated as potentially active
    constant YOUNG_BANK_BITS : natural := 4;
    -- A bank that hasn't been accessed for at least 2^OLD_BANK_BITS is "old"
    -- and is a candidate for immediate precharge and refresh
    constant OLD_BANK_BITS : natural := 7;

    -- Determines polling interval for switching between read requests and write
    -- requests when in polled mode and both sources are fully available.
    constant MUX_POLL_INTERVAL : natural := 255;
    -- Determines hysteresis interval when switching between reads and writes
    constant MUX_SWITCH_DELAY : natural := 7;

    -- Slightly arbitrary decision point for enabling lookahead.  Read lookahead
    -- requires about three more commands lookahead than write.
    constant WRITE_LOOKAHEAD_COUNT : natural := 5;
    constant READ_LOOKAHEAD_COUNT : natural := WRITE_LOOKAHEAD_COUNT + 3;
end;
