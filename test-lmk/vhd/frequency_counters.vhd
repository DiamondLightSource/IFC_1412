-- Array of simple frequency counters

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity frequency_counters is
    generic (
        UPDATE_INTERVAL : natural := 25000000;
        COUNT : natural
    );
    port (
        clk_i : in std_ulogic;

        clk_in_i : in std_ulogic_vector(0 to COUNT-1);
        counts_o : out unsigned_array(0 to COUNT-1)(31 downto 0)
    );
end;

architecture arch of frequency_counters is
    constant UPDATE_BITS : natural := bits(UPDATE_INTERVAL-1);
    signal sample_counter : unsigned(UPDATE_BITS-1 downto 0);
    signal read_request : std_ulogic := '0';
    signal read_ready : std_ulogic_vector(0 to COUNT-1);
    signal counters : unsigned_array(0 to COUNT-1)(31 downto 0);

begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            if sample_counter > 0 then
                sample_counter <= sample_counter - 1;
            else
                sample_counter <= to_unsigned(UPDATE_INTERVAL-1, UPDATE_BITS);
            end if;

            read_request <= to_std_ulogic(sample_counter = 0);

            for i in 0 to COUNT-1 loop
                if read_ready(i) then
                    counts_o(i) <= counters(i);
                end if;
            end loop;
        end if;
    end process;


    gen_counters : for i in 0 to COUNT-1 generate
        signal clock_counter : unsigned(31 downto 0) := (others => '0');
        signal capture_clock : std_ulogic;

    begin
        sync_read : entity work.cross_clocks_read generic map (
            WIDTH => 32
        ) port map (
            clk_in_i => clk_i,
            strobe_i => read_request,
            ack_o => read_ready(i),
            unsigned(data_o) => counters(i),
            clk_out_i => clk_in_i(i),
            strobe_o => capture_clock,
            data_i => std_ulogic_vector(clock_counter),
            ack_i => capture_clock
        );

        process (clk_in_i(i)) begin
            if rising_edge(clk_in_i(i)) then
                if capture_clock then
                    clock_counter <= (others => '0');
                else
                    clock_counter <= clock_counter + 1;
                end if;
            end if;
        end process;
    end generate;
end;
