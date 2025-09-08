-- GDDR6 configuration definitions.  Defines mapping to hardware

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

package gddr6_config_defs is
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
        -- Bank 2 A, bits 32 to 47
        (5,  5),    (4, 10),    (5,  4),    (5, 10),
        (5,  9),    (5, 11),    (5,  3),    (5,  7),
        (4,  4),    (4,  0),    (4,  2),    (4,  9),
        (4,  8),    (4,  5),    (4,  6),    (4,  11),
        -- Bank 2 B, bits 48 to 63
        (7,  2),    (7, 10),    (7,  3),    (7,  9),
        (6, 10),    (7,  7),    (6, 11),    (6,  6),
        (6,  7),    (6,  2),    (6,  3),    (6,  1),
        (6,  0),    (7,  8),    (6,  5),    (6,  4)
    );
    -- DBI
    constant CONFIG_BANK_DBI : pin_config_array_t(0 to 7) := (
        (0,  5),    (1,  4),    -- Bank 1 A
        (2,  9),    (3,  9),    -- Bank 1 B
        (5,  2),    (4,  3),    -- Bank 2 A
        (7,  1),    (6,  9)     -- Bank 2 B
    );
    -- EDC
    constant CONFIG_BANK_EDC : pin_config_array_t(0 to 7) := (
        (0,  0),    (1,  5),    -- Bank 1 A
        (2, 10),    (3,  5),    -- Bank 1 B
        (5,  8),    (4,  1),    -- Bank 2 A
        (7, 11),    (7,  0)     -- Bank 2 B
    );
    -- WCK
    constant CONFIG_BANK_WCK : pin_config_array_t(0 to 1) := (
        (1,  0),                -- Bank 1
        (5,  0)                 -- Bank 2
    );

    -- Patch input for slices which need to be instantiated following the
    -- directions in UG571 (v1.14, p147): clock sink nibbles must instantiate
    -- bitslice 0.  As it happens, only pad_SG12_CK_P meets this description.
    constant CONFIG_BANK_PATCH : pin_config_array_t(0 to 0) := (
        0 => (2,  0)            -- Connected to SG12_CK
    );

    -- Aggregate of all the configs above
    constant CONFIG_BANK_ALL : pin_config_array_t;


    -- Returns bitmask of wanted slices matching the given byte
    function bitslice_wanted(
        byte : natural;
        config : pin_config_array_t := CONFIG_BANK_ALL)
    return std_ulogic_vector;
end;

package body gddr6_config_defs is
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
        CONFIG_BANK_DQ & CONFIG_BANK_DBI & CONFIG_BANK_EDC & CONFIG_BANK_WCK &
        CONFIG_BANK_PATCH;

    function bitslice_wanted(
        byte : natural;
        config : pin_config_array_t := CONFIG_BANK_ALL) return std_ulogic_vector
    is
        variable result : std_ulogic_vector(0 to 11) := (others => '0');
    begin
        for i in config'RANGE loop
            if config(i).byte = byte then
                result(config(i).slice) := '1';
            end if;
        end loop;
        return result;
    end;
end;
