-- Array of simple frequency counters

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity frequency_counters is
    generic (
        -- With a fabric clock of 250 MHz this divider means that each frequency
        -- counter counts for 100ms.
        UPDATE_INTERVAL : natural := 25_000_000;
        COUNT : natural
    );
    port (
        clk_i : in std_ulogic;

        -- Array of clocks to count
        clk_in_i : in std_ulogic_vector(0 to COUNT-1);

        -- Clock counts on clk_i, update_o is strobed every 100ms when counts_o
        -- updates with a new value
        counts_o : out unsigned_array(0 to COUNT-1)(31 downto 0);
        update_o : out std_ulogic := '0'
    );
end;

architecture arch of frequency_counters is
    signal sample_counter : natural range 0 to UPDATE_INTERVAL-1 := 0;
    signal read_request : std_ulogic := '0';
    signal do_update : std_ulogic := '0';
    signal read_ready : std_ulogic_vector(0 to COUNT-1);
    signal counters : unsigned_array(0 to COUNT-1)(31 downto 0);
    signal last_counts : unsigned_array(0 to COUNT-1)(31 downto 0)
        := (others => (others => '0'));
    signal current_counts : unsigned_array(0 to COUNT-1)(31 downto 0)
        := (others => (others => '0'));

begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            if sample_counter > 0 then
                sample_counter <= sample_counter - 1;
            else
                sample_counter <= UPDATE_INTERVAL-1;
            end if;

            read_request <= to_std_ulogic(sample_counter = 0);
            for i in 0 to COUNT-1 loop
                if read_ready(i) then
                    current_counts(i) <= counters(i);
                end if;
            end loop;

            do_update <= to_std_ulogic(sample_counter = UPDATE_INTERVAL/2);
            if do_update then
                for i in 0 to COUNT-1 loop
                    counts_o(i) <= current_counts(i) - last_counts(i);
                end loop;
                last_counts <= current_counts;
            end if;
            update_o <= do_update;
        end if;
    end process;


    gen_counters : for i in 0 to COUNT-1 generate
        signal clock_counter : unsigned(31 downto 0) := (others => '0');

    begin
        -- Pull data across from clk_in_i to clk_i
        sync_read : entity work.cross_clocks_read port map (
            clk_in_i => clk_i,
            strobe_i => read_request,
            ack_o => read_ready(i),
            unsigned(data_o(31 downto 0)) => counters(i),
            clk_out_i => clk_in_i(i),
            data_i(31 downto 0) => std_ulogic_vector(clock_counter)
        );

        process (clk_in_i(i)) begin
            if rising_edge(clk_in_i(i)) then
                clock_counter <= clock_counter + 1;
            end if;
        end process;
    end generate;
end;
