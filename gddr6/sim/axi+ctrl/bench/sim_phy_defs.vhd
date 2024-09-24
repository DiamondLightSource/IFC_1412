-- Helper definitions for PHY+SG simulation

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

use work.gddr6_defs.all;

package sim_phy_defs is
    type sg_address_t is record
        bank : natural;
        row : natural;
        column : natural;
        stage : natural;
    end record;

    type sg_write_mask_t is record
        even_mask : std_ulogic_vector(15 downto 0);
        odd_mask : std_ulogic_vector(15 downto 0);
        enables : std_ulogic_vector(0 to 3);
    end record;

    -- The simulated memory is organised into banks, rows, columns, and bytes
    -- like a real memory, but the number of each is much smaller.
    constant BANK_BITS : natural := 2;          -- 4 on SG
    subtype BANK_RANGE is natural range 0 to 2**BANK_BITS-1;
    constant ROW_BITS : natural := 4;           -- 14 on SG
    subtype ROW_RANGE is natural range 0 to 2**ROW_BITS-1;
    constant COLUMN_BITS : natural := 5;        -- 7 on SG
    subtype COLUMN_RANGE is natural range 0 to 2**COLUMN_BITS-1;
end;
