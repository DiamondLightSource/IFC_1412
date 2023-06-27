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
    signal counts_out : unsigned_array(0 to COUNT-1)(31 downto 0);

    -- The path from counters to counts_out crosses clock domains, but this is
    -- safe ... so long as it doesn't take an excessive time!
    attribute KEEP : string;
    attribute KEEP of counters : signal is "TRUE";
    attribute max_delay_from : string;
    attribute max_delay_from of counters : signal is "TRUE";


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
                    counts_out(i) <= counters(i);
                end if;
            end loop;
        end if;
    end process;
    counts_o <= counts_out;


    gen_counters : for i in 0 to COUNT-1 generate
        signal clock_counter : unsigned(31 downto 0) := (others => '0');
        signal capture_clock : std_ulogic;
        signal capture_ack : std_ulogic := '0';

    begin
        sync_read : entity work.cross_clocks_handshake port map (
            clk_in_i => clk_i,
            strobe_in_i => read_request,
            ack_in_o => read_ready(i),
            clk_out_i => clk_in_i(i),
            strobe_out_o => capture_clock,
            ack_out_i => capture_ack
        );

        process (clk_in_i(i)) begin
            if rising_edge(clk_in_i(i)) then
                if capture_clock then
                    counters(i) <= clock_counter;
                    clock_counter <= (others => '0');
                else
                    clock_counter <= clock_counter + 1;
                end if;
                capture_ack <= capture_clock;
            end if;
        end process;
    end generate;
end;
