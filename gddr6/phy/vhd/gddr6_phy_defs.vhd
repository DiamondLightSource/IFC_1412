-- Shared definitions for PHY support

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

package gddr6_phy_defs is
    -- This clock speed needs to be used by all the slices
    constant REFCLK_FREQUENCY : real := 2000.0;     -- 2 GHz

    type pin_config_t is record
        byte : integer range 0 to 7;    -- Both byte ranges treated together
        slice : integer range 0 to 11;  -- We ignore slice #12 altogether
    end record;

    type pin_config_array_t is array(integer range <>) of pin_config_t;

    -- DQ
    constant CONFIG_BANK_DQ : pin_config_array_t(0 to 63) := (
        -- Bank 1 A, bits 0 to 15
        (0, 11),    (1,  8),    (0,  1),    (1,  9),
        (0,  7),    (0,  9),    (0,  8),    (0,  4),
        (0, 10),    (0,  2),    (0,  6),    (0,  3),
        (1,  7),    (1,  3),    (1,  2),    (1, 11),
        -- Bank 1 B, bits 16 to 31
        (2,  5),    (3,  3),    (2,  6),    (2,  7),
        (2,  8),    (2, 11),    (2,  3),    (2,  2),
        (3,  8),    (3, 10),    (3, 11),    (3,  4),
        (3,  2),    (3,  0),    (2,  4),    (3,  7),
        -- Bank 2 A, bits 0 to 15
        (5,  5),    (4, 10),    (5,  4),    (5, 10),
        (5,  9),    (5, 11),    (5,  3),    (5,  7),
        (4,  4),    (4,  0),    (4,  2),    (4,  9),
        (4,  8),    (4,  5),    (4,  6),    (4,  11),
        -- Bank 2 B, bits 16 to 31
        (7,  2),    (7, 10),    (7,  3),    (7,  9),
        (6, 10),    (7,  7),    (6, 11),    (6,  6),
        (6,  7),    (6,  2),    (6,  3),    (6,  1),
        (6,  0),    (7,  8),    (6,  5),    (6,  4));
    -- DBI
    constant CONFIG_BANK_DBI : pin_config_array_t(0 to 7) := (
        (0,  5),    (1,  4),    -- Bank 1 A
        (2,  9),    (3,  9),    -- Bank 1 B
        (5,  2),    (4,  3),    -- Bank 2 A
        (7,  1),    (6,  9));   -- Bank 2 B
    -- EDC
    constant CONFIG_BANK_EDC : pin_config_array_t(0 to 7) := (
        (0,  0),    (1,  5),    -- Bank 1 A
        (2, 10),    (3,  5),    -- Bank 1 B
        (5,  8),    (4,  1),    -- Bank 2 A
        (7, 11),    (7, 0));    -- Bank 2 B
    -- WCK
    constant CONFIG_BANK_WCK : pin_config_array_t(0 to 1) := (
        (1,  0),                -- Bank 1
        (5,  0));               -- Bank 2

    -- Returns bitmask of wanted slices matching the given byte
    function bitslice_wanted(byte : natural) return std_ulogic_vector;


    -- Helper function used for CABI and DBI calculation
    -- Returns '1' if more than half the bits in input are zeros, which means
    -- that bit inversion is worth invoking
    function compute_bus_inversion(input : std_ulogic_vector) return std_ulogic;
end;

package body gddr6_phy_defs is
    -- Helper for concatenating configurations
    function "&"(left, right : pin_config_array_t) return pin_config_array_t
    is
        constant len_l : natural := left'LENGTH;
        constant len_r : natural := right'LENGTH;
        variable result : pin_config_array_t(0 to len_l+len_r-1);
    begin
        result(0 to len_l-1) := left;
        result(len_l to len_l+len_r-1) := right;
        return result;
    end;

    constant CONFIG_BANK_ALL : pin_config_array_t :=
        CONFIG_BANK_DQ & CONFIG_BANK_DBI & CONFIG_BANK_EDC;

    function bitslice_wanted(byte : natural) return std_ulogic_vector
    is
        variable result : std_ulogic_vector(0 to 11) := (others => '0');
    begin
        for i in CONFIG_BANK_ALL'RANGE loop
            if CONFIG_BANK_ALL(i).byte = byte then
                result(CONFIG_BANK_ALL(i).slice) := '1';
            end if;
        end loop;
        return result;
    end;

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
