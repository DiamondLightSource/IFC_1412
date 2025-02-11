-- Board specific pin swaps on FMC pins

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

package board_fmc_swaps is
    -- Array of bits identifying for each FMC user IO bank which lanes are
    -- swapped on input to the board.  Affected pairs need to be swapped when
    -- assigned to differential IOs, and the bit value needs to be inverted
    constant FMC1_LA_SWAPS : std_ulogic_vector(33 downto 0);
    constant FMC1_HA_SWAPS : std_ulogic_vector(23 downto 0);
    constant FMC1_HB_SWAPS : std_ulogic_vector(21 downto 0);
    constant FMC2_LA_SWAPS : std_ulogic_vector(33 downto 0);
    constant FMC2_HA_SWAPS : std_ulogic_vector(23 downto 0);
    constant FMC2_HB_SWAPS : std_ulogic_vector(21 downto 0);
end;

package body board_fmc_swaps is
    function make_swaps(length : natural; swaps : integer_array)
        return std_ulogic_vector
    is
        variable result : std_ulogic_vector(length-1 downto 0)
            := (others => '0');
    begin
        for i in swaps'RANGE loop
            result(swaps(i)) := '1';
        end loop;
        return result;
    end;


    constant FMC1_LA_SWAPS : std_ulogic_vector := make_swaps(34, (
        3, 4, 5, 6, 7, 8, 9, 11, 13, 14, 15, 16, 19, 20, 22, 23, 24, 28
    ));
    constant FMC1_HA_SWAPS : std_ulogic_vector := make_swaps(24, (
        2, 3, 4, 7, 8, 9, 10, 11, 14, 16, 19, 20, 21, 22, 23
    ));
    constant FMC1_HB_SWAPS : std_ulogic_vector := make_swaps(22, (
        8, 9, 12, 14, 16, 18, 20, 21
    ));

    constant FMC2_LA_SWAPS : std_ulogic_vector := make_swaps(34, (
        2, 4, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16, 27, 28, 29, 30, 31, 32, 33
    ));
    constant FMC2_HA_SWAPS : std_ulogic_vector := make_swaps(24, (
        3, 6, 19, 20, 21, 22, 23
    ));
    constant FMC2_HB_SWAPS : std_ulogic_vector := make_swaps(22, (
        9, 12, 14, 16, 18, 19, 20, 21
    ));
end;
