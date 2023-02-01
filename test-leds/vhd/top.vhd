library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

architecture arch of top is
    signal sysclk_in : std_ulogic;
    signal clk : std_ulogic;

    -- 100 MHz clock divided by 2^23 runs at 12 Hz
    constant PRESCALE_BITS : natural := 23;
    constant COUNTER_WIDTH : natural := PRESCALE_BITS + 2 * 8;
    -- Display the bits with the lowest order bits on the right, namely bit 8 of
    -- the FMC1 LEDs.  As the LED bits are in ascending we get the correct bit
    -- ordering for this display.
    subtype FMC1_BITS is natural range COUNTER_WIDTH-9 downto COUNTER_WIDTH-16;
    subtype FMC2_BITS is natural range COUNTER_WIDTH-1 downto COUNTER_WIDTH-8;

    signal counter : unsigned(COUNTER_WIDTH-1 downto 0) := (others => '0');

begin
    sysclk_ibuf : IBUFDS port map (
        I => pad_SYSCLK100_P,
        IB => pad_SYSCLK100_N,
        O => sysclk_in
    );

    clk_bufg : BUFG port map (
        I => sysclk_in,
        O => clk
    );

    process (clk) begin
        if rising_edge(clk) then
            counter <= counter + 1;
        end if;
    end process;

    pad_FMC1_LED <= std_ulogic_vector(counter(FMC1_BITS));
    pad_FMC2_LED <= std_ulogic_vector(counter(FMC2_BITS));
end;
