-- Test to try and make sense of handshake engine

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity engine is
    port (
        clk_i : in std_ulogic;

        data_i : in std_ulogic_vector;
        extra_i : in std_ulogic;
        valid_i : in std_ulogic;
        ready_o : out std_ulogic;
        ok_i : in std_ulogic;

        data_o : out std_ulogic_vector;
        extra_o : out std_ulogic;
        valid_o : out std_ulogic;
        ready_i : in std_ulogic;
        ok_o : out std_ulogic;

        test_o : out std_ulogic_vector;
        test_valid_o : out std_ulogic;
        test_extra_o : out std_ulogic;
        test_ok_i : in std_ulogic
    );
end;

architecture arch of engine is
    signal data : data_i'SUBTYPE;
    signal ok : std_ulogic := '0';
    signal valid : std_ulogic := '0';
    signal extra : std_ulogic := '0';

    signal ok_in : std_ulogic;
    signal advance : std_ulogic;
    signal test_data : data_i'SUBTYPE;
    signal test_valid : std_ulogic;

    signal extra_in : std_ulogic := '0';
    signal extra_out : std_ulogic := '0';
    signal test_extra : std_ulogic;

begin
    advance <= not valid or (ready_i and ok);

    test_data <= data_i when advance else data;
    test_extra <= extra_in when advance else extra_out;
    test_valid <= valid_i and ok_i when advance else valid;

    test_o <= test_data;
    test_valid_o <= test_valid and not test_extra;
    test_extra_o <= test_extra;
    ok_in <= test_extra or (test_ok_i and test_valid);

    process (clk_i) begin
        if rising_edge(clk_i) then
            if advance then
                data <= data_i;
                valid <= valid_i and ok_i;
                extra_in <= extra_i and valid_i;
                extra_out <= extra_in;
            end if;

            ok <= ok_in;
        end if;
    end process;

    data_o <= data;
    valid_o <= valid;
    extra_o <= extra_out;
    ok_o <= ok;
    ready_o <= advance;
end;
