-- Compute CRC for data passing over the wire to/from SGRAM

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity gddr6_phy_crc is
    port (
        clk_i : in std_ulogic;

        data_i : in vector_array(63 downto 0)(7 downto 0);
        dbi_n_i : in vector_array(7 downto 0)(7 downto 0);

        edc_o : out vector_array(7 downto 0)(7 downto 0)
    );
end;

architecture arch of gddr6_phy_crc is
    -- The following arrays of CRC indices are lifted directly from the CRC
    -- calculation from the polynomial X^8+X^2+X+1 as presented in section 7.14
    -- (page 114) of JEDEC Standard No. 250C, document JESD250C Nov 2018.
    constant CRC0 : integer_array := (
        69, 68, 67, 66, 64, 63, 60, 56, 54, 53, 52, 50, 49, 48, 45, 43,
        40, 39, 35, 34, 31, 30, 28, 23, 21, 19, 18, 16, 14, 12, 8, 7, 6, 0);
    constant CRC1 : integer_array := (
        70, 66, 65, 63, 61, 60, 57, 56, 55, 52, 51, 48, 46, 45, 44, 43,
        41, 39, 36, 34, 32, 30, 29, 28, 24, 23, 22, 21, 20, 18, 17, 16,
        15, 14, 13, 12, 9, 6, 1, 0);
    constant CRC2 : integer_array := (
        71, 69, 68, 63, 62, 61, 60, 58, 57, 54, 50, 48, 47, 46, 44, 43,
        42, 39, 37, 34, 33, 29, 28, 25, 24, 22, 17, 15, 13, 12, 10, 8,
        6, 2, 1, 0);
    constant CRC3 : integer_array := (
        70, 69, 64, 63, 62, 61, 59, 58, 55, 51, 49, 48, 47, 45, 44, 43,
        40, 38, 35, 34, 30, 29, 26, 25, 23, 18, 16, 14, 13, 11, 9, 7, 3, 2, 1);
    constant CRC4 : integer_array := (
        71, 70, 65, 64, 63, 62, 60, 59, 56, 52, 50, 49, 48, 46, 45, 44,
        41, 39, 36, 35, 31, 30, 27, 26, 24, 19, 17, 15, 14,  12, 10, 8,
        4, 3, 2);
    constant CRC5 : integer_array := (
        71, 66, 65, 64, 63, 61, 60, 57, 53, 51, 50, 49, 47, 46, 45, 42,
        40, 37, 36, 32, 31, 28, 27, 25, 20, 18, 16, 15, 13, 11, 9, 5, 4, 3);
    constant CRC6 : integer_array := (
        67, 66, 65, 64, 62, 61, 58, 54, 52, 51, 50, 48, 47, 46, 43, 41,
        38, 37, 33, 32, 29, 28, 26, 21, 19, 17, 16, 14,  12, 10, 6, 5, 4);
    constant CRC7 : integer_array := (
        68, 67, 66, 65, 63, 62, 59, 55, 53, 52, 51, 49, 48, 47, 44, 42,
        39, 38, 34, 33, 30, 29, 27, 22, 20, 18, 17, 15, 13, 11, 7, 6, 5);


    -- The calculation is simply the xor of all the selected indices
    function compute_crc(data : std_ulogic_vector; indices : integer_array)
        return std_ulogic
    is
        variable result : std_ulogic := '0';
    begin
        for i in indices'RANGE loop
            result := result xor data(indices(i));
        end loop;
        return result;
    end;

    signal edc_out : vector_array(7 downto 0)(7 downto 0);

begin
    gen_bank : for bank in 0 to 7 generate
        signal data : std_ulogic_vector(71 downto 0);
    begin
        -- Gather the data as described in section 7.14 (page 111) of JESD250C
        gen_lane : for lane in 0 to 7 generate
            data(8*lane + 7 downto 8 * lane) <= data_i(8 * bank + lane);
        end generate;
        data(71 downto 64) <= dbi_n_i(bank);

        edc_out(bank) <= (
            0 => compute_crc(data, CRC0),
            1 => compute_crc(data, CRC1),
            2 => compute_crc(data, CRC2),
            3 => compute_crc(data, CRC3),
            4 => compute_crc(data, CRC4),
            5 => compute_crc(data, CRC5),
            6 => compute_crc(data, CRC6),
            7 => compute_crc(data, CRC7));
    end generate;

    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Register computed CRC
            edc_o <= edc_out;
        end if;
    end process;
end;
