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

        -- Control parameters.  The upper and lower half banks need different
        -- slip settings as their clocks are (currently) not started together
        rx_slip_i : in unsigned_array(0 to 1)(2 downto 0);
        tx_slip_i : in unsigned_array(0 to 1)(2 downto 0);

        -- Interface to bitslice
        slice_dq_i : in vector_array(63 downto 0)(7 downto 0);
        slice_dq_o : out vector_array(63 downto 0)(7 downto 0);
        slice_dbi_n_i : in vector_array(7 downto 0)(7 downto 0);
        slice_dbi_n_o : out vector_array(7 downto 0)(7 downto 0);
        slice_edc_i : in vector_array(7 downto 0)(7 downto 0);

        -- Corrected data
        fixed_dq_o : out vector_array(63 downto 0)(7 downto 0);
        fixed_dq_i : in vector_array(63 downto 0)(7 downto 0);
        fixed_dbi_n_o : out vector_array(7 downto 0)(7 downto 0);
        fixed_dbi_n_i : in vector_array(7 downto 0)(7 downto 0);
        fixed_edc_o : out vector_array(7 downto 0)(7 downto 0)
    );
end;

architecture arch of gddr6_phy_bitslip is
    signal rx_slip_in : unsigned_array(0 to 1)(2 downto 0);
    signal tx_slip_in : unsigned_array(0 to 1)(2 downto 0);

    signal slice_dq_in : vector_array(63 downto 0)(7 downto 0);
    signal slice_dbi_n_in : vector_array(7 downto 0)(7 downto 0);
    signal slice_edc_in : vector_array(7 downto 0)(7 downto 0);
    signal fixed_dq_in : vector_array(63 downto 0)(7 downto 0);
    signal fixed_dbi_n_in : vector_array(7 downto 0)(7 downto 0);

    function shift_data(
        current : vector_array(open)(7 downto 0);
        previous : vector_array(open)(7 downto 0);
        shift : natural range 0 to 7) return vector_array
    is
        variable result : current'SUBTYPE;
        variable row : std_ulogic_vector(15 downto 0);
    begin
        for i in result'RANGE loop
            row := previous(i) & current(i);
            result(i) := row(shift + 7 downto shift);
        end loop;
        return result;
    end;

    function bitslip(
        current : vector_array(open)(7 downto 0);
        previous : vector_array(open)(7 downto 0);
        shifts : unsigned_array(0 to 1)(2 downto 0)) return vector_array
    is
        constant WIDTH : natural := current'LENGTH;
        subtype LOW_RANGE is natural range WIDTH/2 - 1 downto 0;
        subtype HIGH_RANGE is natural range WIDTH - 1 downto WIDTH/2;
        constant low_shift : natural := to_integer(shifts(0));
        constant high_shift : natural := to_integer(shifts(1));
        variable result : vector_array(WIDTH-1 downto 0)(7 downto 0);

    begin
        result(LOW_RANGE) := shift_data(
            current(LOW_RANGE), previous(LOW_RANGE), low_shift);
        result(HIGH_RANGE) := shift_data(
            current(HIGH_RANGE), previous(HIGH_RANGE), high_shift);
        return result;
    end;

begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Local copy of slip parameters
            rx_slip_in <= rx_slip_i;
            tx_slip_in <= tx_slip_i;

            -- Remember previous values
            slice_dq_in <= slice_dq_i;
            slice_dbi_n_in <= slice_dbi_n_i;
            slice_edc_in <= slice_edc_i;
            fixed_dq_in <= fixed_dq_i;
            fixed_dbi_n_in <= fixed_dbi_n_i;

            -- Do the shifts
            fixed_dq_o    <= bitslip(slice_dq_i,    slice_dq_in,    rx_slip_in);
            slice_dq_o    <= bitslip(fixed_dq_i,    fixed_dq_in,    tx_slip_in);
            fixed_dbi_n_o <= bitslip(slice_dbi_n_i, slice_dbi_n_in, rx_slip_in);
            slice_dbi_n_o <= bitslip(fixed_dbi_n_i, fixed_dbi_n_in, tx_slip_in);
            fixed_edc_o   <= bitslip(slice_edc_i,   slice_edc_in,   rx_slip_in);
        end if;
    end process;
end;
