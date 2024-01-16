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
    type delay_control_t is record
        up_down_n : std_ulogic;
        -- DQ RX
        dq_rx_vtc : std_ulogic_vector(63 downto 0);
        dq_rx_ce : std_ulogic_vector(63 downto 0);
        -- DQ TX
        dq_tx_vtc : std_ulogic_vector(63 downto 0);
        dq_tx_ce : std_ulogic_vector(63 downto 0);
        dq_tx_bitslip : std_ulogic_vector(63 downto 0);
        -- DBI RX
        dbi_rx_vtc : std_ulogic_vector(7 downto 0);
        dbi_rx_ce : std_ulogic_vector(7 downto 0);
        -- DBI TX
        dbi_tx_vtc : std_ulogic_vector(7 downto 0);
        dbi_tx_ce : std_ulogic_vector(7 downto 0);
        dbi_tx_bitslip : std_ulogic_vector(7 downto 0);
        -- EDC
        edc_rx_vtc : std_ulogic_vector(7 downto 0);
        edc_rx_ce : std_ulogic_vector(7 downto 0);
        -- Delay associated by bitslip strobes above
        bitslip_delay : unsigned(2 downto 0);
    end record;

    -- Delay readbacks from _dq to _delay_control
    type delay_readbacks_t is record
        dq_rx_delay : vector_array(63 downto 0)(8 downto 0);
        dq_tx_delay : vector_array(63 downto 0)(8 downto 0);
        dbi_rx_delay : vector_array(7 downto 0)(8 downto 0);
        dbi_tx_delay : vector_array(7 downto 0)(8 downto 0);
        edc_rx_delay : vector_array(7 downto 0)(8 downto 0);
    end record;


    -- Helper function used for CABI and DBI calculation
    -- Returns '1' if more than half the bits in input are zeros, which means
    -- that bit inversion is worth invoking
    function compute_bus_inversion(input : std_ulogic_vector) return std_ulogic;
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
end;
