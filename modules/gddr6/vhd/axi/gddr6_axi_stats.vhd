-- Gather and register AXI statistics

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gddr6_defs.all;
use work.gddr6_ip_defs.all;
use work.gddr6_axi_defs.all;

entity gddr6_axi_stats is
    port (
        clk_i : in std_ulogic;

        write_stats_i : in raw_stats_t;
        read_stats_i : in raw_stats_t;

        axi_stats_o : out axi_stats_t := (others => '0')
    );
end;

architecture arch of gddr6_axi_stats is
begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            axi_stats_o <= (
                write_frame_error => write_stats_i.frame_error,
                write_crc_error => write_stats_i.crc_error,
                write_last_error => write_stats_i.last_error,
                write_address => write_stats_i.address,
                write_transfer => write_stats_i.transfer,
                write_data_beat => write_stats_i.data_beat,

                read_frame_error => read_stats_i.frame_error,
                read_crc_error => read_stats_i.crc_error,
                read_address => read_stats_i.address,
                read_transfer => read_stats_i.transfer,
                read_data_beat => read_stats_i.data_beat
            );
        end if;
    end process;
end;
