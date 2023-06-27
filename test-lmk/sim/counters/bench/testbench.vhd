library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;

use work.support.all;

entity testbench is
end testbench;

architecture arch of testbench is
    signal clk : std_ulogic := '0';

    constant COUNT : natural := 4;
    constant UPDATE_INTERVAL : natural := 100;

    signal clk_in : std_ulogic_vector(0 to COUNT-1) := (others => '0');
    signal counts : unsigned_array(0 to COUNT-1)(31 downto 0);

    type time_array is array(natural range <>) of time;
    signal tick_time : time_array(0 to COUNT-1)
        := (1 ns, 2.1 ns, 4 ns, 220 ns);

begin
    clk <= not clk after 2 ns;
    gen_clk_in : for i in 0 to COUNT-1 generate
        clk_in(i) <= not clk_in(i) after tick_time(i);
    end generate;

    counters : entity work.frequency_counters generic map (
        UPDATE_INTERVAL => UPDATE_INTERVAL,
        COUNT => COUNT
    ) port map (
        clk_i => clk,
        clk_in_i => clk_in,
        counts_o => counts
    );
end;
