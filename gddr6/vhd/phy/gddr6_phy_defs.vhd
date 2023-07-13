-- Shared definitions for PHY support

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

package gddr6_phy_defs is
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
