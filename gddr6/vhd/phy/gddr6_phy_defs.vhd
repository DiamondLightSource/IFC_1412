-- Shared definitions for PHY support

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

package gddr6_phy_defs is
    -- Sub address decoding for delays
    subtype DELAY_DQ_RANGE is natural range 63 downto 0;
    subtype DELAY_DBI_RANGE is natural range 71 downto 64;
    subtype DELAY_EDC_RANGE is natural range 79 downto 72;

    -- Controls from _delay_control to _dq and _dq_remap
    type bitslice_delay_control_t is record
        up_down_n : std_ulogic;
        dq_rx_ce : std_ulogic_vector(63 downto 0);
        dq_tx_ce : std_ulogic_vector(63 downto 0);
        dbi_rx_ce : std_ulogic_vector(7 downto 0);
        dbi_tx_ce : std_ulogic_vector(7 downto 0);
        edc_rx_ce : std_ulogic_vector(7 downto 0);
    end record;

    -- Delay readbacks from _dq to _delay_control
    type bitslice_delay_readbacks_t is record
        dq_rx_delay : vector_array(63 downto 0)(8 downto 0);
        dq_tx_delay : vector_array(63 downto 0)(8 downto 0);
        dbi_rx_delay : vector_array(7 downto 0)(8 downto 0);
        dbi_tx_delay : vector_array(7 downto 0)(8 downto 0);
        edc_rx_delay : vector_array(7 downto 0)(8 downto 0);
    end record;

    -- Controls over bitslip delay
    type bitslip_delay_control_t is record
        -- Strobes for setting TX delay
        dq_tx_strobe : std_ulogic_vector(63 downto 0);
        dbi_tx_strobe : std_ulogic_vector(7 downto 0);
        -- Strobes for setting RX delay
        dq_rx_strobe : std_ulogic_vector(63 downto 0);
        dbi_rx_strobe : std_ulogic_vector(7 downto 0);
        edc_rx_strobe : std_ulogic_vector(7 downto 0);
        -- Delay set by strobes above
        delay : unsigned(2 downto 0);
    end record;

    type bitslip_delay_readbacks_t is record
        dq_tx_delay : unsigned_array(63 downto 0)(2 downto 0);
        dbi_tx_delay : unsigned_array(7 downto 0)(2 downto 0);
        dq_rx_delay : unsigned_array(63 downto 0)(2 downto 0);
        dbi_rx_delay : unsigned_array(7 downto 0)(2 downto 0);
        edc_rx_delay : unsigned_array(7 downto 0)(2 downto 0);
    end record;


    -- Helper function used for CABI and DBI calculation
    -- Returns '1' if more than half the bits in input are zeros, which means
    -- that bit inversion is worth invoking
    function compute_bus_inversion(input : std_ulogic_vector) return std_ulogic;

    constant IDLE_BITSLICE_DELAY_CONTROL : bitslice_delay_control_t;
    constant IDLE_BITSLIP_DELAY_CONTROL : bitslip_delay_control_t;
end;

package body gddr6_phy_defs is
    function compute_bus_inversion(input : std_ulogic_vector) return std_ulogic
    is
        variable zero_count : natural := 0;
    begin
        for i in input'RANGE loop
            if input(i) = '0' then
                zero_count := zero_count + 1;
            end if;
        end loop;
        -- If more than half the bits are zeros it will be worth inverting them
        return to_std_ulogic(zero_count > input'LENGTH / 2);
    end;

    constant IDLE_BITSLICE_DELAY_CONTROL : bitslice_delay_control_t := (
        up_down_n => '0',
        dq_rx_ce => (others => '0'),
        dq_tx_ce => (others => '0'),
        dbi_rx_ce => (others => '0'),
        dbi_tx_ce => (others => '0'),
        edc_rx_ce => (others => '0')
    );

    constant IDLE_BITSLIP_DELAY_CONTROL : bitslip_delay_control_t := (
        dq_tx_strobe => (others => '0'),
        dbi_tx_strobe => (others => '0'),
        dq_rx_strobe => (others => '0'),
        dbi_rx_strobe => (others => '0'),
        edc_rx_strobe => (others => '0'),
        delay => (others => '0')
    );
end;
