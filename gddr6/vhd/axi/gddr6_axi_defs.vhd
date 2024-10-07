-- AXI specific definitions

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;

package gddr6_axi_defs is
    -- -------------------------------------------------------------------------
    -- Internal FIFO interfaces

    -- Transfer address for generating SG bursts required to fill the requested
    -- AXI burst.  Passed to CTRL layer
    type address_t is record
        address : unsigned(24 downto 0);    -- First SG burst address
        count : unsigned(4 downto 0);       -- Count of SG bursts
        valid : std_ulogic;
    end record;

    -- Command information for transferring data for an AXI burst
    type burst_command_t is record
        id : std_ulogic_vector(3 downto 0); -- AXI transfer ID
        count : unsigned(7 downto 0);       -- Length of AXI burst
        offset : unsigned(6 downto 0);      -- Burst start offset in SG burst
        step : unsigned(6 downto 0);        -- Offset step per burst
        invalid_burst : std_ulogic;         -- Set if no data transferred
        valid : std_ulogic;
    end record;

    -- Command information for write response handling.  Similar to burst
    -- control but without the address offset information
    type burst_response_t is record
        id : std_ulogic_vector(3 downto 0); -- AXI transfer ID
        count : unsigned(4 downto 0);       -- Count of SG bursts
        invalid_burst : std_ulogic;         -- Set if no data transferred
        valid : std_ulogic;
    end record;

    -- Interface to write data fifo
    type write_data_t is record
        data : std_ulogic_vector(511 downto 0);
        byte_mask : std_ulogic_vector(63 downto 0);
        phase : std_ulogic;
        advance : std_ulogic;
        valid : std_ulogic;
    end record;

    -- Interface to read data fifo
    type read_data_t is record
        data : std_ulogic_vector(511 downto 0);
        ok : std_ulogic;
        valid : std_ulogic;
    end record;

    -- Internal statistics events
    type raw_stats_t is record
        -- Framing error in address request
        frame_error : std_ulogic;
        -- CRC error in response from CTRL
        crc_error : std_ulogic;
        -- Only valid for write: framing error for write burst
        last_error : std_ulogic;

        -- Address accepted
        address : std_ulogic;
        -- Transfer completed: end of read or B command accepted for write
        transfer : std_ulogic;
        -- Data beat completed
        data_beat : std_ulogic;
    end record;


    constant IDLE_ADDRESS : address_t;
    constant IDLE_BURST_COMMAND : burst_command_t;
    constant IDLE_BURST_RESPONSE : burst_response_t;
    constant IDLE_WRITE_DATA : write_data_t;
    constant IDLE_READ_DATA : read_data_t;
end;

package body gddr6_axi_defs is
    constant IDLE_ADDRESS : address_t := (
        address => (others => '0'),
        count => (others => '0'),
        valid => '0'
    );

    constant IDLE_BURST_COMMAND : burst_command_t := (
        id => (others => '0'),
        count => (others => '0'),
        offset => (others => '0'),
        step => (others => '0'),
        invalid_burst => '0',
        valid => '0'
    );

    constant IDLE_BURST_RESPONSE : burst_response_t := (
        id => (others => '0'),
        count => (others => '0'),
        invalid_burst => '0',
        valid => '0'
    );

    constant IDLE_WRITE_DATA : write_data_t := (
        data => (others => '0'),
        byte_mask => (others => '0'),
        phase => '0',
        advance => '0',
        valid => '0'
    );

    constant IDLE_READ_DATA : read_data_t := (
        data => (others => '0'),
        ok => '0',
        valid => '0'
    );
end;
