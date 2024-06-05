-- AXI specific definitions

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

package gddr6_axi_defs is
    -- -------------------------------------------------------------------------
    -- AXI stread interfaces: AW, W, B, AR, R

    -- AW and AR are the same
    type axi_address_t is record
        id : std_logic_vector(3 downto 0);
        addr : unsigned(31 downto 0);
        len : unsigned(7 downto 0);
        size : unsigned(2 downto 0);
        burst : std_ulogic_vector(1 downto 0);
        valid : std_ulogic;
    end record;

    -- W
    type axi_write_data_t is record
        data : std_logic_vector(511 downto 0);
        strb : std_ulogic_vector(63 downto 0);
        last : std_logic;
        valid : std_ulogic;
    end record;

    -- B
    type axi_write_response_t is record
        id : std_logic_vector(3 downto 0);
        resp : std_logic_vector(1 downto 0);
        valid : std_ulogic;
    end record;

    -- R
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
        address : unsigned(24 downto 0);
        count : unsigned(4 downto 0);
        valid : std_ulogic;
    end record;

    -- Command information for transferring data for an AXI burst
    type burst_command_t is record
        id : std_ulogic_vector(3 downto 0); -- AXI transfer ID
        count : unsigned(7 downto 0);       -- Length of burst
        offset : unsigned(6 downto 0);      -- Burst start offset in SG burst
        step : unsigned(6 downto 0);        -- Offset step per burst
        invalid_burst : std_ulogic;         -- Set if no data transferred
        valid : std_ulogic;
    end record;


    constant IDLE_ADDRESS : address_t;
    constant IDLE_BURST_COMMAND : burst_command_t;
    constant IDLE_AXI_READ_DATA : axi_read_data_t;
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

    constant IDLE_AXI_READ_DATA : axi_read_data_t := (
        id => (others => '0'),
        data => (others => '0'),
        resp => (others => '0'),
        last => '0',
        valid => '0'
    );
end;
