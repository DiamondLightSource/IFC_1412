-- Implements bit level phase shift on raw data stream

-- This processing is used to compensate for WCK phase discrepancies relative
-- to CK.
--    The name "bitslip" is something of a historical misnomer arising from
-- true bitslip functionality provided by earlier generations of SERDES devices;
-- the code here is a simple select 8 from 15 sliding shift register.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity gddr6_phy_bitslip is
    port (
        clk_i : in std_ulogic;

        -- Delay to set
        delay_i : in unsigned(2 downto 0);
        -- Strobe to configure individual delay
        strobe_i : in std_ulogic_vector;
        -- Delay readbacks
        delay_o : out unsigned_array(open)(2 downto 0);

        -- Data in and out
        data_i : in vector_array(open)(7 downto 0);
        data_o : out vector_array(open)(7 downto 0)
    );
end;

architecture arch of gddr6_phy_bitslip is
    subtype BIT_ARRAY_RANGE is natural range strobe_i'RANGE;

    signal bitslip : unsigned_array(BIT_ARRAY_RANGE)(2 downto 0)
        := (others => (others => '0'));
    signal bit_arrays : vector_array(BIT_ARRAY_RANGE)(15 downto 0);

    signal delay_strobe_in : std_ulogic_vector(BIT_ARRAY_RANGE);
    signal delay_in : unsigned(2 downto 0);

begin
    -- Writing selected delay
    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Allow for more placement optimisation by pipelining this write
            delay_strobe_in <= strobe_i;
            delay_in <= delay_i;

            for i in BIT_ARRAY_RANGE loop
                if delay_strobe_in(i) then
                    bitslip(i) <= delay_in;
                end if;
            end loop;
        end if;
    end process;
    delay_o <= bitslip;


    -- Process all bits
    gen_bits : for bit in BIT_ARRAY_RANGE generate
        -- The first byte is just a copy of the original data
        bit_arrays(bit)(15 downto 8) <= data_i(bit);

        process (clk_i)
            variable shift : natural range 0 to 7;
        begin
            if rising_edge(clk_i) then
                -- The rest of the array remembers older bits
                bit_arrays(bit)(7 downto 0) <= bit_arrays(bit)(15 downto 8);

                -- Select desired output
                shift := to_integer(bitslip(bit));
                data_o(bit) <= bit_arrays(bit)(15 - shift downto 8 - shift);
            end if;
        end process;
    end generate;
end;
