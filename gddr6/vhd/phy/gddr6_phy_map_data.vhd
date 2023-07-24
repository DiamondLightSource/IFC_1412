-- Perform data remapping and DBI correction if required

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.gddr6_phy_defs.all;

entity gddr6_phy_map_data is
    port (
        clk_i : in std_ulogic;

        enable_dbi_i : in std_ulogic;

        -- Signals from bitslices grouped into ticks
        bank_data_i : in vector_array(63 downto 0)(7 downto 0);
        bank_data_o : out vector_array(63 downto 0)(7 downto 0);
        bank_dbi_n_i : in vector_array(7 downto 0)(7 downto 0);
        bank_dbi_n_o : out vector_array(7 downto 0)(7 downto 0);

        -- Flattened and DBI processed signals leaving PHY layer
        data_o : out std_ulogic_vector(511 downto 0);
        data_i : in std_ulogic_vector(511 downto 0)
    );
end;

architecture arch of gddr6_phy_map_data is
    -- Data path from DRAM: bank_data_i -> data_in => data_o
    signal data_in : std_ulogic_vector(511 downto 0);
    -- Data path to DRAM: data_i -> bank_data_out => bank_data_o
    signal bank_data_out : vector_array(63 downto 0)(7 downto 0);
    signal bank_dbi_n_out : vector_array(7 downto 0)(7 downto 0);

    -- Gathered from bank_dbi_n_i and masked
    signal invert_bits_in : vector_array(7 downto 0)(7 downto 0);
    -- Computed from outgoing data
    signal invert_bits_out : vector_array(7 downto 0)(7 downto 0);

begin
    -- Gather the DBI control bits.  For outgoing data we need to inspect the
    -- data (after reshaping) to determine if DBI is wanted.
    gen_dbi : for lanes in 0 to 7 generate
        -- For incoming data we just obey the incoming bits for each group of
        -- lanes
        invert_bits_in(lanes) <= enable_dbi_i and not bank_dbi_n_i(lanes);

        -- For outgoing data we need to inspect our dataset for each tick to
        -- determine whether to enable DBI inversion
        gen_ticks : for tick in 0 to 7 generate
            -- Getting the byte for DBI output is surprisingly tricky as input
            -- bytes are laid out in consecutive ticks.  Each lane group indexed
            -- by lanes represents a group of 8 bytes.
            impure function invert_bits return std_ulogic is
                variable byte : std_ulogic_vector(7 downto 0);
            begin
                for i in 0 to 7 loop
                    -- Select outgoing bits for the same tick in the selected
                    -- byte group
                    byte(i) := data_i(lanes * 64 + 8 * i + tick);
                end loop;
                return compute_bus_inversion(byte);
            end;
        begin
            invert_bits_out(lanes)(tick) <= invert_bits;
            bank_dbi_n_out(lanes)(tick) <= not invert_bits;
        end generate;
    end generate;


    -- Gather bytes across banks, each lane contains data for one byte.
    gen_bytes : for lane in 0 to 63 generate
        subtype BYTE_RANGE is natural range 8 * lane + 7 downto 8 * lane;
    begin
        data_in(BYTE_RANGE) <= invert_bits_in(lane/8)  xor bank_data_i(lane);
        bank_data_out(lane) <= invert_bits_out(lane/8) xor data_i(BYTE_RANGE);
    end generate;


    -- Register incoming and outgoing data
    process (clk_i) begin
        if rising_edge(clk_i) then
            data_o <= data_in;
            bank_data_o <= bank_data_out;
            bank_dbi_n_o <= bank_dbi_n_out;
        end if;
    end process;
end;
