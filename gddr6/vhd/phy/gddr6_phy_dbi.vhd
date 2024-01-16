-- Perform any required DBI processing

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.gddr6_phy_defs.all;

entity gddr6_phy_dbi is
    port (
        clk_i : in std_ulogic;

        enable_dbi_i : in std_ulogic;

        -- Data to memory
        data_out_i : in vector_array(63 downto 0)(7 downto 0);
        dbi_n_out_o : out vector_array(7 downto 0)(7 downto 0);
        data_out_o : out vector_array(63 downto 0)(7 downto 0);

        -- Data from memory
        data_in_i : in vector_array(63 downto 0)(7 downto 0);
        dbi_n_in_i : in vector_array(7 downto 0)(7 downto 0);
        data_in_o : out vector_array(63 downto 0)(7 downto 0);

        -- DBI training support
        enable_training_i : in std_ulogic;
        train_dbi_n_i : in vector_array(7 downto 0)(7 downto 0);
        train_dbi_n_o : out vector_array(7 downto 0)(7 downto 0)
    );
end;

architecture arch of gddr6_phy_dbi is
    -- Pipelined copy of enable_dbi_i
    signal enable_dbi_in : std_ulogic;

    -- Gathered from dbi_n_in_i and masked by enable_dbi_i
    signal invert_bits_in : vector_array(7 downto 0)(7 downto 0);
    -- Computed from outgoing data and masked by enable_dbi_i
    signal invert_bits_out : vector_array(7 downto 0)(7 downto 0);


    -- Computes whether to invert the outgoing bits for the selected group of
    -- output bits and selected tick.
    function invert_bits(
        bank_data_in : vector_array(63 downto 0)(7 downto 0);
        lane : natural; tick : natural) return std_ulogic
    is
        variable byte : std_ulogic_vector(7 downto 0);
    begin
        for i in 0 to 7 loop
            byte(i) := bank_data_in(lane*8 + i)(tick);
        end loop;
        return compute_bus_inversion(byte);
    end;


    function "not"(value : vector_array) return vector_array
    is
        variable result : value'SUBTYPE;
    begin
        for i in value'RANGE loop
            result(i) := not value(i);
        end loop;
        return result;
    end;

begin
    -- Gather the DBI control bits.  For outgoing data we need to inspect the
    -- data (after reshaping) to determine if DBI is wanted.
    gen_dbi : for lane in 0 to 7 generate
        -- For incoming data we just obey the incoming bits for each group of
        -- lane
        invert_bits_in(lane) <= enable_dbi_in and not dbi_n_in_i(lane);

        -- For outgoing data we need to inspect our dataset for each tick to
        -- determine whether to enable DBI inversion
        gen_ticks : for tick in 0 to 7 generate
            invert_bits_out(lane)(tick) <=
                enable_dbi_in and invert_bits(data_out_i, lane, tick);
        end generate;
    end generate;


    -- Register incoming and outgoing data
    process (clk_i) begin
        if rising_edge(clk_i) then
            enable_dbi_in <= enable_dbi_i;

            -- Invert data bits as appropriate
            for wire in 0 to 63 loop
                data_in_o(wire) <=
                    invert_bits_in(wire/8)  xor data_in_i(wire);
                data_out_o(wire) <=
                    invert_bits_out(wire/8) xor data_out_i(wire);
            end loop;

            -- During training we send the training DBI out
            if enable_training_i then
                dbi_n_out_o <= train_dbi_n_i;
            else
                dbi_n_out_o <= not invert_bits_out;
            end if;

            train_dbi_n_o <= dbi_n_in_i;
        end if;
    end process;
end;
