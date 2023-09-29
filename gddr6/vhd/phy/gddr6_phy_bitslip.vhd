-- Implements bit level phase shift on raw data stream

-- This processing is used to compensate for WCK phase discrepancies relative
-- to CK.  If WCK can be started synchronously it may be possible to eliminate
-- this fairly costly processing.
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

        -- Control interface.  Each bit needs a separate control, and a shift of
        -- up to 7 bits can be selected
        delay_i : in unsigned(2 downto 0);
        -- The bits are addressed as follows:
        --  63..0  => Selects DQ input
        --  71..64 => Selectes DBI input
        --  79..72 => Selects EDC input
        delay_address_i : in unsigned(6 downto 0);
        delay_strobe_i : in std_ulogic;

        -- Interface to bitslice
        slice_dq_i : in vector_array(63 downto 0)(7 downto 0);
        slice_dbi_n_i : in vector_array(7 downto 0)(7 downto 0);
        slice_edc_i : in vector_array(7 downto 0)(7 downto 0);

        -- Corrected data
        fixed_dq_o : out vector_array(63 downto 0)(7 downto 0);
        fixed_dbi_n_o : out vector_array(7 downto 0)(7 downto 0);
        fixed_edc_o : out vector_array(7 downto 0)(7 downto 0)
    );
end;

architecture arch of gddr6_phy_bitslip is
    subtype BIT_ARRAY_RANGE is natural range 79 downto 0;
    signal bitslip : unsigned_array(BIT_ARRAY_RANGE)(2 downto 0)
        := (others => (others => '0'));
    signal bit_arrays_in : vector_array(BIT_ARRAY_RANGE)(7 downto 0);
    signal bit_arrays : vector_array(BIT_ARRAY_RANGE)(15 downto 0);
    signal bit_arrays_out : vector_array(BIT_ARRAY_RANGE)(7 downto 0);

    signal delay_strobe_in : std_ulogic := '0';
    signal delay_address_in : natural range 0 to 79;
    signal delay_in : unsigned(2 downto 0);

begin
    -- Writing selected delay
    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Allow for more placement optimisation by pipelining this write
            delay_strobe_in <= delay_strobe_i;
            delay_address_in <= to_integer(delay_address_i);
            delay_in <= delay_i;

            if delay_strobe_in then
                bitslip(delay_address_in) <= delay_in;
            end if;
        end if;
    end process;

    -- Map incoming bits
    bit_arrays_in <= (
        63 downto 0 => slice_dq_i,
        71 downto 64 => slice_dbi_n_i,
        79 downto 72 => slice_edc_i
    );

    -- Process all bits
    gen_bits : for bit in BIT_ARRAY_RANGE generate
        -- The first byte is just a copy of the original data
        bit_arrays(bit)(15 downto 8) <= bit_arrays_in(bit);

        process (clk_i)
            variable shift : natural range 0 to 7;
        begin
            if rising_edge(clk_i) then
                -- The rest of the array remembers older bits
                bit_arrays(bit)(7 downto 0) <= bit_arrays(bit)(15 downto 8);

                -- Select desired output
                shift := to_integer(bitslip(bit));
                bit_arrays_out(bit) <=
                    bit_arrays(bit)(15 - shift downto 8 - shift);
            end if;
        end process;
    end generate;

    -- Finally map shifted bit arrays out
    fixed_dq_o <= bit_arrays_out(63 downto 0);
    fixed_dbi_n_o <= bit_arrays_out(71 downto 64);
    fixed_edc_o <= bit_arrays_out(79 downto 72);
end;
