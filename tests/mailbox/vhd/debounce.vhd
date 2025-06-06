-- Simple debounce
-- Introduces a minimum delay of 2+DEBOUNCE_DELAY ticks

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debounce is
    generic (
        DEBOUNCE_DELAY : natural
    );
    port (
        clk_i : in std_ulogic;

        signal_i : in std_ulogic;
        signal_o : out std_ulogic := '0'
    );
end;

architecture arch of debounce is
    signal counter : natural range 0 to DEBOUNCE_DELAY := DEBOUNCE_DELAY;
    signal last_signal : std_ulogic := '0';

begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            last_signal <= signal_i;
            if last_signal /= signal_i then
                counter <= DEBOUNCE_DELAY;
            elsif counter > 0 then
                counter <= counter - 1;
            else
                signal_o <= signal_i;
            end if;
        end if;
    end process;
end;
