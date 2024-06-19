-- AXI specific definitions

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

package gddr6_axi_defs is
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


    constant IDLE_AXI_READ_DATA : axi_read_data_t;
    constant IDLE_AXI_WRITE_DATA : axi_write_data_t;
    constant IDLE_AXI_WRITE_RESPONSE : axi_write_response_t;

    constant IDLE_ADDRESS : address_t;
    constant IDLE_BURST_COMMAND : burst_command_t;
    constant IDLE_BURST_RESPONSE : burst_response_t;
    constant IDLE_WRITE_DATA : write_data_t;
    constant IDLE_READ_DATA : read_data_t;
end;

package body gddr6_axi_defs is
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
