-- Perform data remapping

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
        bank_edc_i : in vector_array(7 downto 0)(7 downto 0);

        -- Processed signals leaving PHY layer
        data_o : out std_ulogic_vector(511 downto 0);
        data_i : in std_ulogic_vector(511 downto 0);
        edc_o : out std_ulogic_vector(63 downto 0)
    );
end;

architecture arch of gddr6_phy_map_data is
    signal data_out : std_ulogic_vector(511 downto 0);
    signal edc_out : std_ulogic_vector(63 downto 0);

begin
    gen_ticks : for tick in 0 to 7 generate
        gen_bytes : for byte in 0 to 7 generate
            -- Offset into tick selection of this byte
            constant BANK_OFFSET : natural := 8 * byte;
            -- Offset into processed word of this byte
            constant WORD_OFFSET : natural := 64 * tick + BANK_OFFSET;
            subtype WORD_BYTE_RANGE is natural
                range WORD_OFFSET + 7 downto WORD_OFFSET;

            signal invert_bits_in : std_ulogic;
            signal invert_bits_out : std_ulogic;

        begin
            -- Incoming data from edge, use DBI from memory
            invert_bits_in <= enable_dbi_i and not bank_dbi_n_i(byte)(tick);
            -- Outgoing data, compute DBI for each byte
            invert_bits_out <= enable_dbi_i and
                compute_bus_inversion(data_i(WORD_BYTE_RANGE));

            -- We can't slice inner dimensions, so have to extract bit by bit
            gen_bits : for bit in 0 to 7 generate
                data_out(WORD_OFFSET + bit) <=
                    invert_bits_in xor bank_data_i(BANK_OFFSET + bit)(tick);
                bank_data_o(BANK_OFFSET + bit)(tick) <=
                    invert_bits_out xor data_i(WORD_OFFSET + bit);
            end generate;

            bank_dbi_n_o(byte)(tick) <= not invert_bits_out;
            edc_out(8*tick + byte) <= bank_edc_i(byte)(tick);
        end generate;
    end generate;

    process (clk_i) begin
        if rising_edge(clk_i) then
            data_o <= data_out;
            edc_o <= edc_out;

            -- We may want to register bank_data as well depending on timing and
            -- placement pressure.
        end if;
    end process;
end;
