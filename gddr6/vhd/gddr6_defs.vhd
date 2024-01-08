-- Interface definitions for GDDR6

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

package gddr6_defs is
    -- Controls for setting delays
    type setup_delay_t is record
        -- The address map is as follows:
        --   0aaaaaa    Control DQ bit selected by aaaaaaa
        --   1000aaa    Control DBI bit selected by aaa
        --   1001aaa    Control EDC bit selected by aaa (input only)
        --   111xxxx    (unassigned)
        address : unsigned(6 downto 0);
        -- Target selection:
        --   00         Control or read IDELAY
        --   01         Control or read ODELAY
        --   10         (unassigned)
        --   11         Control or read output BITSLIP
        target : unsigned(1 downto 0);

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
        -- Hack to disable VTC
        disable_vtc : std_ulogic;
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
