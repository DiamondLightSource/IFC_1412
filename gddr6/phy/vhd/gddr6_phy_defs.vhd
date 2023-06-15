-- Shared definitions for PHY support

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

package gddr6_phy_defs is
    -- This clock speed needs to be used by all the slices
    constant REFCLK_FREQUENCY : real := 2000.0;     -- 2 GHz

    type pin_config_t is record
        byte : integer;
        slice : integer;
    end record;

    type pin_config_array_t is array(integer range <>) of pin_config_t;

    -- IO bank 1 (lower 32 bits of DQ)
    constant CONFIG_BANK1_DQ : pin_config_array_t(0 to 31) := (
        -- Bank A, bits 0 to 15
        (0, 11),    (1,  8),    (0,  1),    (1,  9),
        (0,  7),    (0,  9),    (0,  8),    (0,  4),
        (0, 10),    (0,  2),    (0,  6),    (0,  3),
        (1,  7),    (1,  3),    (1,  2),    (1, 11),
        -- Bank B, bits 16 to 31
        (2,  5),    (3,  3),    (2,  6),    (2,  7),
        (2,  8),    (2, 11),    (2,  3),    (2,  2),
        (3,  8),    (3, 10),    (3, 11),    (3,  4),
        (3,  2),    (3,  0),    (2,  4),    (3,  7));
    constant CONFIG_BANK1_DBI : pin_config_array_t(0 to 3) := (
        (0,  5),    (1,  4),    (2,  9),    (3,  9));
    constant CONFIG_BANK1_EDC : pin_config_array_t(0 to 3) := (
        (0,  0),    (1,  5),    (2, 10),    (3,  5));

    -- IO bank 2 (upper 32 bits of DQ)
    constant CONFIG_BANK2_DQ : pin_config_array_t(0 to 31) := (
        -- Bank A, bits 0 to 15
        (1,  5),    (0, 10),    (1,  4),    (1, 10),
        (1,  9),    (1, 11),    (1,  3),    (1,  7),
        (0,  4),    (0,  0),    (0,  2),    (0,  9),
        (0,  8),    (0,  5),    (0,  6),    (0,  11),
        -- Bank B, bits 16 to 31
        (3,  2),    (3, 10),    (3,  3),    (3,  9),
        (2, 10),    (3,  7),    (2, 11),    (2,  6),
        (2,  7),    (2,  2),    (2,  3),    (2,  1),
        (2,  0),    (3,  8),    (2,  5),    (2,  4));
    constant CONFIG_BANK2_DBI : pin_config_array_t(0 to 3) := (
        (1,  2),    (0,  3),    (3,  1),    (2,  9));
    constant CONFIG_BANK2_EDC : pin_config_array_t(0 to 3) := (
        (1,  8),    (0,  1),    (3, 11),    (3, 0));


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
