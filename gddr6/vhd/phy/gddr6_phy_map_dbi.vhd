-- Perform data remapping and DBI correction if required

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.gddr6_phy_defs.all;

entity gddr6_phy_map_dbi is
    port (
        clk_i : in std_ulogic;

        enable_dbi_i : in std_ulogic;

        -- Signals from bitslices grouped into ticks
        bank_data_i : in vector_array(63 downto 0)(7 downto 0);
        bank_data_o : out vector_array(63 downto 0)(7 downto 0);
        bank_dbi_n_i : in vector_array(7 downto 0)(7 downto 0);
        bank_dbi_n_o : out vector_array(7 downto 0)(7 downto 0);

        -- DBI training support
        enable_training_i : in std_ulogic;
        train_dbi_n_i : in vector_array(7 downto 0)(7 downto 0);
        train_dbi_n_o : out vector_array(7 downto 0)(7 downto 0);

        -- Flattened and DBI processed signals leaving PHY layer
        data_o : out std_ulogic_vector(511 downto 0);
        data_i : in std_ulogic_vector(511 downto 0)
    );
end;

architecture arch of gddr6_phy_map_dbi is
    signal enable_dbi_in : std_ulogic;

    -- Data path from DRAM: bank_data_i -> data_in => data_o
    signal data_in : std_ulogic_vector(511 downto 0);
    -- Data path to DRAM: data_i -> bank_data_out => bank_data_o
    signal bank_data_out : vector_array(63 downto 0)(7 downto 0);
    signal bank_dbi_n_out : vector_array(7 downto 0)(7 downto 0);

    signal bank_data_in : vector_array(63 downto 0)(7 downto 0);

    -- Gathered from bank_dbi_n_i and masked
    signal invert_bits_in : vector_array(7 downto 0)(7 downto 0);
    -- Computed from outgoing data
    signal invert_bits_out : vector_array(7 downto 0)(7 downto 0);

    -- Computes whether to invert the outgoing bits for the selected group of
    -- output bits and selected tick.
    function invert_bits(
        bank_data_in : vector_array(63 downto 0)(7 downto 0);
        lanes: natural; tick : natural) return std_ulogic
    is
        variable byte : std_ulogic_vector(7 downto 0);
    begin
        for i in 0 to 7 loop
            byte(i) := bank_data_in(lanes*8 + i)(tick);
        end loop;
        return compute_bus_inversion(byte);
    end;

begin
    -- Gather the DBI control bits.  For outgoing data we need to inspect the
    -- data (after reshaping) to determine if DBI is wanted.
    gen_dbi : for lanes in 0 to 7 generate
        -- For incoming data we just obey the incoming bits for each group of
        -- lanes
        invert_bits_in(lanes) <= enable_dbi_in and not bank_dbi_n_i(lanes);

        -- For outgoing data we need to inspect our dataset for each tick to
        -- determine whether to enable DBI inversion
        gen_ticks : for tick in 0 to 7 generate
            invert_bits_out(lanes)(tick) <=
                enable_dbi_in and invert_bits(bank_data_in, lanes, tick);
        end generate;
        bank_dbi_n_out(lanes) <= not invert_bits_out(lanes);
    end generate;


    -- Gather bytes across banks, each lane contains data for one byte,
    -- corresponding to one IO line
    gen_bytes : for lane in 0 to 63 generate
        subtype BYTE_RANGE is natural range 8 * lane + 7 downto 8 * lane;
    begin
        -- Data from bitslice
        data_in(BYTE_RANGE) <= invert_bits_in(lane/8)  xor bank_data_i(lane);

        -- Data to bitslice
        bank_data_in(lane) <= data_i(BYTE_RANGE);
        bank_data_out(lane) <= invert_bits_out(lane/8) xor bank_data_in(lane);
    end generate;


    -- Register incoming and outgoing data
    process (clk_i) begin
        if rising_edge(clk_i) then
            enable_dbi_in <= enable_dbi_i;

            data_o <= data_in;
            bank_data_o <= bank_data_out;
            if enable_training_i then
                bank_dbi_n_o <= train_dbi_n_i;
            else
                bank_dbi_n_o <= bank_dbi_n_out;
            end if;

            train_dbi_n_o <= bank_dbi_n_i;
        end if;
    end process;
end;
