-- GDDR6 definitions for internally shared definitions

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

package gddr6_defs is
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- Interfaces between AXI and CTRL

    type axi_request_t is record
        -- WA Write Adddress
        wa_address : unsigned(24 downto 0);
        wa_byte_mask : std_ulogic_vector(127 downto 0);
        wa_valid : std_ulogic;
        -- WA Lookahead
        wal_address : unsigned(24 downto 0);
        wal_count : unsigned(4 downto 0);
        wal_valid : std_ulogic;
        -- RA Read Address
        ra_address : unsigned(24 downto 0);
        ra_valid : std_ulogic;
        -- RA Lookahead
        ral_address : unsigned(24 downto 0);
        ral_count : unsigned(4 downto 0);
        ral_valid : std_ulogic;
        -- WD Write Data
        -- Data is organised by channel and flattened into 16 bytes per channel
        -- to reflect the flow required to match byte masks.
        wd_data : vector_array(0 to 3)(127 downto 0);
    end record;

    type axi_response_t is record
        -- WA Write Adddress
        wa_ready : std_ulogic;
        -- RA Read Address
        ra_ready : std_ulogic;
        -- WD Write Data
        wd_advance : std_ulogic;
        wd_ready : std_ulogic;
        -- WR Write Response
        wr_ok : std_ulogic;
        wr_ok_valid : std_ulogic;
        -- RD Read Data
        rd_data : vector_array(0 to 3)(127 downto 0);
        rd_valid : std_ulogic;
        rd_ok : std_ulogic;
        rd_ok_valid : std_ulogic;
    end record;


    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- Interfaces between CTRL (and SETUP) and PHY

    -- CA command
    type phy_ca_t is record
        -- Bit 3 in the second tick, ca_i(1)(3), can be overridden by ca3_i.
        -- To allow this set ca_i(1)(3) to '0', then ca3_i(n) will be used.
        ca : vector_array(0 to 1)(9 downto 0);
        ca3 : std_ulogic_vector(0 to 3);
        -- Clock enable, held low during normal operation
        cke_n : std_ulogic;
    end record;

    -- Data out and controls
    -- Data is transferred in a burst of 128 bytes over two ticks, and so is
    -- organised here as an array of 64 bytes, or 512 bits, with each byte
    -- containing data from a single wire.
    type phy_dq_out_t is record
        -- Data to send to memory
        data : vector_array(63 downto 0)(7 downto 0);
        -- Due to an extra delay in the BITSLICE output stages output_enable_i
        -- must be presented 1 CK tick earlier than data_i.
        output_enable : std_ulogic;
    end record;

    -- Data in from PHY
    type phy_dq_in_t is record
        -- Data received from memory
        data : vector_array(63 downto 0)(7 downto 0);
        -- EDC support.  edc_in_o is the code received from memory and must be
        -- compared with edc_write_o for written data and edc_read_o for read
        edc_in : vector_array(7 downto 0)(7 downto 0);
        edc_write : vector_array(7 downto 0)(7 downto 0);
        edc_read : vector_array(7 downto 0)(7 downto 0);
    end record;


    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- Interfaces between SETUP and PHY

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
        --   10         Control or read input BITSLIP
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
        -- Directly driven resets to the two GDDR6 devices.  Should be held low
        -- until ca_i has been properly set for configuration options.
        sg_resets_n : std_ulogic_vector(0 to 1);
        -- Data bus inversion enables for CA and DQ interfaces
        enable_cabi : std_ulogic;
        enable_dbi : std_ulogic;
        -- If this is set then dbi_n_i is used to train DBI output.  In this
        -- enable_dbi should not be set.
        train_dbi : std_ulogic;
        -- Must be held low during SG reset, high during normal operation
        edc_tri : std_ulogic;

        -- Special fudge for prototype board, must be removed.  Used to work
        -- around sticky CA6 bit.
        fudge_sticky_ca6 : std_ulogic;
    end record;

    -- Readbacks from PHY
    type phy_status_t is record
        -- This indicates that FIFO reset has been successful, and will go low
        -- if FIFO underflow or overflow is detected.
        fifo_ok : std_ulogic_vector(0 to 1);
    end record;


    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- Interfaces between SETUP and CTRL

    type ctrl_setup_t is record
        enable_refresh : std_ulogic;
        priority_mode : std_ulogic;
        priority_direction : std_ulogic;
    end record;

    type ctrl_status_t is record
        read_error : std_ulogic;
        write_error : std_ulogic;
    end record;

end;
