-- Interface definitions for GDDR6

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

package gddr6_defs is
    -- Controls for setting delays
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
        -- Set this to enable writing the delay, otherwise only the readback is
        -- updated (where appropriate).
        enable_write : std_ulogic;
        -- Strobes for read and write.
        write_strobe : std_ulogic;
        read_strobe : std_ulogic;
    end record;

    -- Readback and handshakes from delays
    type setup_delay_result_t is record
        write_ack : std_ulogic;
        -- Acknowledge for reading.  To avoid reading invalid data while a
        -- write is in progress a read_strobe->read_ack handshake should be
        -- completed before reading delay.
        read_ack : std_ulogic;
        delay : unsigned(8 downto 0);
    end record;


    -- Configuration settings for PHY
    type phy_setup_t is record
        -- Can be used to hold the RX FIFO in reset
        reset_fifo : std_ulogic_vector(0 to 1);
        -- Directly driven resets to the two GDDR6 devices.  Should be held low
        -- until ca_i has been properly set for configuration options.
        sg_resets_n : std_ulogic_vector(0 to 1);
        -- Data bus inversion enables for CA and DQ interfaces
        enable_cabi : std_ulogic;
        enable_dbi : std_ulogic;
        -- If this flag is set then DBI is captured as edc_out_o
        capture_dbi : std_ulogic;
        -- This delay is used to align data_o with data_i so that edc_out_o can
        -- be computed correctly
        edc_delay : unsigned(4 downto 0);
        -- Must be held low during SG reset, high during normal operation
        edc_tri : std_ulogic;

        -- Special fudge for prototype board, must be removed.  Used to work
        -- around sticky CA6 bit.
        fudge_sticky_ca6 : std_ulogic;
    end record;

    -- Readbacks from PHY
    type phy_status_t is record
        -- This is asserted for one tick immediately after relocking if the CK
        -- PLL unlocks.
        ck_unlock : std_ulogic;
        -- This indicates that FIFO reset has been successful, and will go low
        -- if FIFO underflow or overflow is detected.
        fifo_ok : std_ulogic_vector(0 to 1);
    end record;
end;
