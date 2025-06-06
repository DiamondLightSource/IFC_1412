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


    -- Top level AXI interface
    -- -------------------------------------------------------------------------
    -- AXI stream interfaces: AW, W, B, AR, R

    -- AXI AW and AR are the same
    type axi_address_t is record
        id : std_logic_vector(3 downto 0);
        addr : unsigned(31 downto 0);
        len : unsigned(7 downto 0);
        size : unsigned(2 downto 0);
        burst : std_ulogic_vector(1 downto 0);
        valid : std_ulogic;
    end record;

    -- AXI W
    type axi_write_data_t is record
        data : std_logic_vector(511 downto 0);
        strb : std_ulogic_vector(63 downto 0);
        last : std_logic;
        valid : std_ulogic;
    end record;

    -- AXI B
    type axi_write_response_t is record
        id : std_logic_vector(3 downto 0);
        resp : std_logic_vector(1 downto 0);
        valid : std_ulogic;
    end record;

    -- AXI R
    type axi_read_data_t is record
        id : std_logic_vector(3 downto 0);
        data : std_logic_vector(511 downto 0);
        resp : std_logic_vector(1 downto 0);
        last : std_logic;
        valid : std_ulogic;
    end record;


    constant IDLE_AXI_ADDRESS : axi_address_t;
    constant IDLE_AXI_READ_DATA : axi_read_data_t;
    constant IDLE_AXI_WRITE_DATA : axi_write_data_t;
    constant IDLE_AXI_WRITE_RESPONSE : axi_write_response_t;


    -- From master to slave
    type axi_request_t is record
        write_address : axi_address_t;
        write_data : axi_write_data_t;
        write_response_ready : std_ulogic;
        read_address : axi_address_t;
        read_data_ready : std_ulogic;
    end record;

    -- From slave to master
    type axi_response_t is record
        write_address_ready : std_ulogic;
        write_data_ready : std_ulogic;
        write_response : axi_write_response_t;
        read_address_ready : std_ulogic;
        read_data : axi_read_data_t;
    end record;


    constant IDLE_AXI_REQUEST : axi_request_t;
    constant IDLE_AXI_RESPONSE : axi_response_t;


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
        -- For IDELAY and ODELAY and phase controls direction of stepping
        up_down_n : std_ulogic;
        -- Set this to enable writing the delay, otherwise only the readback is
        -- updated (where appropriate).
        enable_write : std_ulogic;

        -- Strobes for read and write.
        write_strobe : std_ulogic;
        read_strobe : std_ulogic;

        -- Trigger step of phase
        phase_strobe : std_ulogic;
    end record;

    -- Readback and handshakes from delays
    type setup_delay_result_t is record
        write_ack : std_ulogic;
        -- Acknowledge for reading.  To avoid reading invalid data while a
        -- write is in progress a read_strobe->read_ack handshake should be
        -- completed before reading delay.
        read_ack : std_ulogic;
        delay : unsigned(8 downto 0);
        -- Acknowledge and readback for fine clock phase control
        phase_ack : std_ulogic;
        phase : unsigned(7 downto 0);
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

    type sg_temperature_t is record
        -- Each temperature is encoded as 0.5*(degrees+40) in Centigrade, so
        -- display as 2*t-40.
        temperature : unsigned_array(0 to 3)(7 downto 0);
        -- This interface is designed to be used asynchronously: use the rising
        -- edge of valid (after synchronising to the target clock) to locally
        -- register temperature.  This is updated every millisecond.
        valid : std_ulogic;
    end record;

    constant INVALID_TEMPERATURE : sg_temperature_t;
end;

package body gddr6_defs is
    constant IDLE_AXI_ADDRESS : axi_address_t := (
        id => (others => '0'),
        addr => (others => '0'),
        len => (others => '0'),
        size => (others => '0'),
        burst => (others => '0'),
        valid => '0'
    );

    constant IDLE_AXI_READ_DATA : axi_read_data_t := (
        id => (others => '0'),
        data => (others => '0'),
        resp => (others => '0'),
        last => '0',
        valid => '0'
    );

    constant IDLE_AXI_WRITE_DATA : axi_write_data_t := (
        data => (others => '0'),
        strb => (others => '0'),
        last => '0',
        valid => '0'
    );

    constant IDLE_AXI_WRITE_RESPONSE : axi_write_response_t := (
        id => (others => '0'),
        resp => (others => '0'),
        valid => '0'
    );


    constant IDLE_AXI_REQUEST : axi_request_t := (
        write_address => IDLE_AXI_ADDRESS,
        write_data => IDLE_AXI_WRITE_DATA,
        write_response_ready => '0',
        read_address => IDLE_AXI_ADDRESS,
        read_data_ready => '0'
    );

    constant IDLE_AXI_RESPONSE : axi_response_t := (
        write_address_ready => '0',
        write_data_ready => '0',
        write_response => IDLE_AXI_WRITE_RESPONSE,
        read_address_ready => '0',
        read_data => IDLE_AXI_READ_DATA
    );


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

    constant INVALID_TEMPERATURE : sg_temperature_t := (
        temperature => (others => (others => '0')),
        valid => '0'
    );
end;
