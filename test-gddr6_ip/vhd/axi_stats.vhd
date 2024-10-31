-- Gather AXI statistics

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.gddr6_defs.all;

entity axi_stats is
    port (
        clk_i : in std_ulogic;
        reset_i : in std_ulogic;
        axi_stats_i : in std_ulogic_vector(0 to 10);
        stats_o : out reg_data_array_t(0 to 10)
    );
end;

architecture arch of axi_stats is
    subtype STATS_RANGE is natural range 0 to 10;
    signal stats : unsigned_array(STATS_RANGE)(31 downto 0)
        := (others => (others => '0'));

begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            if reset_i then
                stats <= (others => (others => '0'));
            else
                for i in STATS_RANGE loop
                    if axi_stats_i(i) and
                       to_std_ulogic(stats(i) /= max_uint(32)) then
                        stats(i) <= stats(i) + 1;
                    end if;
                end loop;
            end if;
            stats_o <= reg_data_array_t(stats);
        end if;
    end process;
end;
