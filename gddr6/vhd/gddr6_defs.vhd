-- Interface definitions for GDDR6

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

package gddr6_defs is
    type setup_delay_t is record
        -- The address map is as follows:
        --   00aaaaaa    Control IDELAY for DQ bit selected by aaaaaaa
        --   01aaaaaa    Control ODELAY for DQ bit selected by aaaaaaa
        --   10aaaaaa    Set bitslip input for selected DQ bit
        --   11000aaa    Set bitslip input for DBI bit aaa
        --   11001aaa    Set bitslip input for EDC bit aaa
        --   11010aaa    Control IDELAY for DBI bit aaa
        --   11011aaa    Control ODELAY for DBI bit aaa
        --   11100aaa    Control IDELAY for EDC bit aaa
        --   11101xxx    (unassigned)
        --   1111cccc    Control ODELAY for CA bit selected by cccc:
        --               0..9        CA[cccc] (cccc = 3 is ignored)
        --               10          CABI_N
        --               11..14      CA3[cccc-11]
        --               15          CKE_N
        address : unsigned(7 downto 0);
        -- Delay to be written.  For IDELAY and ODELAY settings the delay is
        -- stepped by the selected amount rather than updated, for bitslip the
        -- delay is written directly (from delay[0:2]).
        delay : unsigned(8 downto 0);
        -- For IDELAY and ODELAY controls direction of stepping
        up_down_n : std_ulogic;
        -- Selecting write of byteslip.  This only affects DQ, DBI, EDC inputs,
        -- and all other fields are ignored.
        byteslip : std_ulogic;
        -- Set this to enable writing the delay, otherwise only the readback is
        -- updated (where appropriate).
        enable_write : std_ulogic;
        -- Strobes for read and write.
        write_strobe : std_ulogic;
        read_strobe : std_ulogic;
    end record;

    type setup_delay_result_t is record
        write_ack : std_ulogic;
        -- Acknowledge for reading.  To avoid reading invalid data while a
        -- write is in progress a read_strobe->read_ack handshake should be
        -- completed before reading delay.
        read_ack : std_ulogic;
        delay : unsigned(8 downto 0);
    end record;
end;
