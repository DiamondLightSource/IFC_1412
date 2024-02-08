-- Timing definitions for controller.  All times in multiples of t_CK

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package gddr6_ctrl_timing_defs is
    -- These settings are configured in the mode registers

    -- Write latency, delay from write command to data transmission MR0[2:0]
    constant WLmrs : natural := 5;
    -- Read latency, delay from read command to transmission MR0[6:3]
    constant RLmrs : natural := 9;

    -- Delay from write data to EDC output MR4[6:4]
    constant CRCWL : natural := 10;
    -- Delay from read data to EDC output MR4[6:4]
    constant CRCRL : natural := 2;

    -- These settings are taken from table 47 (AC Timing)

    -- Minimum time before closing a row after activation
    constant t_RAS : natural := 7;      -- MAX(4, 28/t_CK)
    -- Minimum time from ACT to first read command
    constant t_RCDRD : natural := 5;    -- 18 ns
    -- Minimum time from ACT to first write command
    constant t_RCDWR : natural := 1;    -- MAX(1, t_RCDRD - 1 - WLmrs)
    -- Minimum delay from PRE to ACT on same bank
    constant t_RP : natural := 5;       -- 17 ns
    -- Minimum time interval between successive ACT commands on the same bank
    constant t_RC : natural := t_RAS + t_RP;    -- 45 ns

    -- Write recovery time, time from end of write to precharge
    constant t_WR : natural := 5;       -- 18 ns (at 0 to 95 degrees C)
    -- Time from write to command to precharge
    constant t_WTP : natural := WLmrs + 2 + t_WR;   -- 12
    -- Time from read to precharge
    constant t_RTP : natural := 2;

    -- Minimum delay betwen ATC commands on different banks
    constant t_RRD : natural := 2;

    -- Time for REFab to complete
    constant t_RFCab : natural := 28;   -- 110 ns
    -- Time for REFp2b to complete
    constant t_RFCpb : natural := 14;   -- tRAS + 25 ns

    -- Write turnaround time: time from completion of write to read command
    constant t_WTR : natural := 3;      -- 2 + 4/t_CK
    -- This is the actual WR to RD time calculated from the documentation
    constant t_WTR_time : natural := WLmrs + 2 + t_WTR;
    -- Read turnaround time: time from read to write commands
    constant t_RTW : natural := RLmrs + 4 - WLmrs;  -- 8

    -- Required periodic refresh interval
    constant t_REFI : natural := 475;   -- 1.9 microseconds
    -- Interval for periodic full refresh in multiples of t_REFI
    constant t_ABREF_REFI : natural := 526;     -- 1 ms / 1.9 microseconds
end;
