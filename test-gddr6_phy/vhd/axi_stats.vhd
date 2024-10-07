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
        axi_stats_i : in axi_stats_t;
        stats_o : out reg_data_array_t(0 to 10)
    );
end;

architecture arch of axi_stats is
    subtype STATS_RANGE is natural range 0 to 10;
    signal events : std_ulogic_vector(STATS_RANGE);
    signal stats : unsigned_array(STATS_RANGE)(31 downto 0)
        := (others => (others => '0'));

begin
    events <= (
        0  => axi_stats_i.write_frame_error,
        1  => axi_stats_i.write_crc_error,
        2  => axi_stats_i.write_last_error,
        3  => axi_stats_i.write_address,
        4  => axi_stats_i.write_transfer,
        5  => axi_stats_i.write_data_beat,
        6  => axi_stats_i.read_frame_error,
        7  => axi_stats_i.read_crc_error,
        8  => axi_stats_i.read_address,
        9  => axi_stats_i.read_transfer,
        10 => axi_stats_i.read_data_beat
    );

    process (clk_i) begin
        if rising_edge(clk_i) then
            if reset_i then
                stats <= (others => (others => '0'));
            else
                for i in STATS_RANGE loop
                    if events(i) and stats(i) ?/= max_uint(32) then
                        stats(i) <= stats(i) + 1;
                    end if;
                end loop;
            end if;
            stats_o <= reg_data_array_t(stats);
        end if;
    end process;
end;
