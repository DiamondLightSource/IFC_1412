-- GDDR6 definitions for internally shared definitions

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

package gddr6_defs is
    -- Various arrays of data types

    -- PHY data is organised by wire and by tick, directly representing how it
    -- is transferred to and from IO BITSLICEs
    subtype phy_data_t is vector_array(63 downto 0)(7 downto 0);
    subtype phy_edc_t is vector_array(7 downto 0)(7 downto 0);
    subtype phy_dbi_t is vector_array(7 downto 0)(7 downto 0);
    subtype axi_data_t is std_ulogic_vector(511 downto 0);

    -- CTRL data is organised by channel and word, reflecing the relationship
    -- with write enable arrays
    subtype ctrl_data_t is vector_array(0 to 3)(127 downto 0);

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- Interfaces between AXI and CTRL

    -- Read

    type axi_ctrl_read_request_t is record
        -- RA Read Address
        ra_address : unsigned(24 downto 0);
        ra_valid : std_ulogic;
        -- RA Lookahead
        ral_address : unsigned(24 downto 0);
        ral_count : unsigned(4 downto 0);
        ral_valid : std_ulogic;
    end record;

    type axi_ctrl_read_response_t is record
        -- RA Read Address
        ra_ready : std_ulogic;
        -- RD Read Data
        rd_data : ctrl_data_t;
        rd_valid : std_ulogic;
        rd_ok : std_ulogic;
        rd_ok_valid : std_ulogic;
    end record;

    constant IDLE_AXI_CTRL_READ_REQUEST : axi_ctrl_read_request_t;
    constant IDLE_AXI_CTRL_READ_RESPONSE : axi_ctrl_read_response_t;

    -- Write

    type axi_ctrl_write_request_t is record
        -- WA Write Adddress
        wa_address : unsigned(24 downto 0);
        wa_byte_mask : std_ulogic_vector(127 downto 0);
        wa_valid : std_ulogic;
        -- WA Lookahead
        wal_address : unsigned(24 downto 0);
        wal_count : unsigned(4 downto 0);
        wal_valid : std_ulogic;
        -- WD Write Data
        -- Data is organised by channel and flattened into 16 bytes per channel
        -- to reflect the flow required to match byte masks.
        wd_data : ctrl_data_t;
    end record;

    type axi_ctrl_write_response_t is record
        -- WA Write Adddress
        wa_ready : std_ulogic;
        -- WD Write Data
        wd_advance : std_ulogic;
        wd_ready : std_ulogic;
        -- WR Write Response
        wr_ok : std_ulogic;
        wr_ok_valid : std_ulogic;
    end record;

    constant IDLE_AXI_CTRL_WRITE_REQUEST : axi_ctrl_write_request_t;
    constant IDLE_AXI_CTRL_WRITE_RESPONSE : axi_ctrl_write_response_t;


    -- Event bits recording various AXI events.  Each bit is strobed when the
    -- corresponding event occurs
    type axi_stats_t is record
        write_frame_error : std_ulogic;     -- Invalid write address request
        write_crc_error : std_ulogic;       -- Write CRC error reported
        write_last_error : std_ulogic;      -- Data burst framing error

        write_address : std_ulogic;         -- Write address accepted
        write_transfer : std_ulogic;        -- Write transfer completed
        write_data_beat : std_ulogic;       -- Single write data transfer

        read_frame_error : std_ulogic;      -- Invalid read address request
        read_crc_error : std_ulogic;        -- Read CRC error reported

        read_address : std_ulogic;          -- Read address accepted
        read_transfer : std_ulogic;         -- Read transfer completed
        read_data_beat : std_ulogic;        -- Single read data transfer
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
        data : phy_data_t;
        -- Due to an extra delay in the BITSLICE output stages output_enable_i
        -- must be presented 1 CK tick earlier than data_i.
        output_enable : std_ulogic;
    end record;

    -- Data in from PHY
    type phy_dq_in_t is record
        -- Data received from memory
        data : phy_data_t;
        -- EDC support.  edc_in_o is the code received from memory and must be
        -- compared with edc_write_o for written data and edc_read_o for read
        edc_in : phy_edc_t;
        edc_write : phy_edc_t;
        edc_read : phy_edc_t;
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
    end record;

    -- Readbacks from PHY
    type phy_status_t is record
        -- This indicates that FIFO reset has been successful, and will go low
        -- if FIFO underflow or overflow is detected.
        fifo_ok : std_ulogic_vector(0 to 1);
    end record;


    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- Interfaces from SETUP to CTRL

    type ctrl_setup_t is record
        -- These will normally be enabled together
        enable_axi : std_ulogic;
        enable_refresh : std_ulogic;
        -- Determines the priority selection mode for the read/write multiplexer
        -- If set to '1' then the preferred direction as selected by
        -- priority_direction is used whenever possible, otherwise the preferred
        -- direction alternates over time to implement round-robin scheduling
        priority_mode : std_ulogic;
        -- When priority_mode = '1' selects the preferred direction:
        --  '0' => reads take priority over writes
        --  '1' => write take priority over reads
        priority_direction : std_ulogic;
    end record;
end;

package body gddr6_defs is
    constant IDLE_AXI_CTRL_READ_REQUEST : axi_ctrl_read_request_t := (
        ra_address => (others => '0'),
        ra_valid => '0',
        ral_address => (others => '0'),
        ral_count => (others => '0'),
        ral_valid => '0'
    );

    constant IDLE_AXI_CTRL_READ_RESPONSE : axi_ctrl_read_response_t := (
        ra_ready => '0',
        rd_data => (others => (others => '0')),
        rd_valid => '0',
        rd_ok => '0',
        rd_ok_valid => '0'
    );

    constant IDLE_AXI_CTRL_WRITE_REQUEST : axi_ctrl_write_request_t := (
        wa_address => (others => '0'),
        wa_byte_mask => (others => '0'),
        wa_valid => '0',
        wal_address => (others => '0'),
        wal_count => (others => '0'),
        wal_valid => '0',
        wd_data => (others => (others => '0'))
    );

    constant IDLE_AXI_CTRL_WRITE_RESPONSE : axi_ctrl_write_response_t := (
        wa_ready => '0',
        wd_advance => '0',
        wd_ready => '0',
        wr_ok => '0',
        wr_ok_valid => '0'
    );
end;
