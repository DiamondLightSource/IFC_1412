-- Core SPI implementation

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity flash_spi_core is
    port (
        clk_i : in std_ulogic;

        -- SPI interface
        spi_clk_o : out std_ulogic := '0';
        spi_cs_n_o : out std_ulogic := '1';
        spi_mosi_o : out std_ulogic := '1';
        spi_miso_i : in std_ulogic;

        -- Control settings
        read_delay_i : in unsigned(2 downto 0);
        clock_speed_i : in unsigned(1 downto 0);
        long_cs_high_i : in std_ulogic;

        -- Data transfer interface
        data_mo_i : in std_ulogic_vector(7 downto 0);
        data_mi_o : out std_ulogic_vector(7 downto 0);
        data_mi_valid_o : out std_ulogic := '0';
        data_mi_last_o : out std_ulogic := '0';

        -- Triggers start of SPI exchange
        start_i : in std_ulogic;
        -- Must be asserted during last byte to send
        last_i : in std_ulogic;
        -- Asserted when data from SO is to be captured
        read_enable_i : in std_ulogic;
        -- Asserted when ready to read the next byte
        next_o : out std_ulogic;
        -- Asserted during transaction
        busy_o : out std_ulogic := '0'
    );
end;

architecture arch of flash_spi_core is
    -- There is an unexpected amount of signal skew introduced by the STARTUPE3.
    -- The relevant delays are:
    --  cs_n    1 to 8.6 ns     CS#
    --  clk     1 to 7.5 ns     SCK
    --  mosi    1 to 8.4 ns
    --  miso    0.5 to 3.5 ns
    -- To all of these we'll need to add let's say 1 ns of routing delay.  Data
    -- setup and hold will mostly be managed by reducing the clock speed as
    -- necessary and configuring the read dealay if appropriate, but we need to
    -- manage CS# to SCK timing with care.
    --  The main constraints are CS# low to first SCK rising edge given by
    -- t_CSS >= 10 ns, last SCK rising edge to CS# low given by t_CSH >= 3 ns,
    -- and minimum CS# time T_CS >= 10 ns or 50 ns for writes.
    --  Adding in allowance for skew we get:
    --      t_CSS >= 10 + 7.6 or 5 ticks
    --      t_CSH >= 3 + 6.5 or 3 ticks
    --      t_CS = 3 ticks or 13 ticks

    -- Delay before starting clock after CS goes low.  Takes into account both
    -- the possible skew between CLK and CS (as large as 14.1 ns according to
    -- DS892 for STARTUPE3) and tCSS.
    constant START_DELAY : natural := 4;
    constant SHORT_END_DELAY : natural := 4;
    constant LONG_END_DELAY : natural := 12;

    -- We support a variety of SPI clock speeds from 125 MHz to 31 MHz.  The
    -- rated speed (according to table 14 of the datasheet) is 66 MHz, but this
    -- may need to be downgraded to allow for extra skew on the signals.
    signal clock_counter : unsigned(1 downto 0);
    -- Set on tick before falling edge of spi_clk
    signal falling_edge : std_ulogic;

    signal bit_counter : natural range 0 to 7;
    signal last_bit : std_ulogic;

    type state_t is (SPI_IDLE, SPI_STARTING, SPI_ACTIVE, SPI_ENDING);
    signal state : state_t := SPI_IDLE;
    signal state_counter : natural range 0 to 15;

    -- MI data handling
    -- The read delay is designed so that the earliest possible data result will
    -- be at the start of the delay pipeline, so we need 8 ticks plus an
    -- for the minimum round trip delay.
    constant READ_DELAY : natural := 12;
    signal mi_pipeline : std_ulogic_vector(0 to 7);

    signal read_bit_strobe : std_ulogic;
    signal read_last_bit : std_ulogic;
    signal read_last_byte : std_ulogic;

begin
    falling_edge <= spi_clk_o and to_std_ulogic(clock_counter = 0);

    delay_read : entity work.fixed_delay generic map (
        DELAY => READ_DELAY,
        WIDTH => 3
    ) port map (
        clk_i => clk_i,
        data_i(0) => falling_edge,
        data_i(1) => to_std_ulogic(bit_counter = 0) and read_enable_i,
        data_i(2) => last_i,
        data_o(0) => read_bit_strobe,
        data_o(1) => read_last_bit,
        data_o(2) => read_last_byte
    );


    process (clk_i) begin
        if rising_edge(clk_i) then
            next_o <= '0';
            case state is
                when SPI_IDLE =>
                    if start_i then
                        spi_cs_n_o <= '0';
                        clock_counter <= clock_speed_i;

                        -- Load the first bit
                        spi_mosi_o <= data_mo_i(7);
                        bit_counter <= 6;
                        last_bit <= '0';

                        state_counter <= START_DELAY;
                        state <= SPI_STARTING;
                    end if;

                when SPI_STARTING =>
                    -- Wait for startup delay
                    if state_counter > 0 then
                        state_counter <= state_counter - 1;
                    else
                        state <= SPI_ACTIVE;
                    end if;

                when SPI_ACTIVE =>
                    -- Maintain SPI clock
                    if clock_counter = 0 then
                        clock_counter <= clock_speed_i;
                        spi_clk_o <= not spi_clk_o;
                    else
                        clock_counter <= clock_counter - 1;
                    end if;

                    -- Update state and output on falling edge
                    if falling_edge then
                        if last_bit then
                            spi_mosi_o <= '1';

                            if long_cs_high_i then
                                state_counter <= LONG_END_DELAY;
                            else
                                state_counter <= SHORT_END_DELAY;
                            end if;
                            state <= SPI_ENDING;
                        else
                            -- Load data out on falling edge of SPI clock
                            spi_mosi_o <= data_mo_i(bit_counter);
                            bit_counter <= (bit_counter - 1) mod 8;

                            -- Advance state on last bit
                            if bit_counter = 0 then
                                -- We've consumed the entire byte
                                next_o <= '1';
                                last_bit <= last_i;
                            end if;
                        end if;
                    end if;

                when SPI_ENDING =>
                    -- Deassert CS_n once last bit was sent
                    spi_cs_n_o <= '1';

                    -- Wait for runout delay
                    if state_counter > 0 then
                        state_counter <= state_counter - 1;
                    else
                        state <= SPI_IDLE;
                    end if;
            end case;

            -- Read processing
            -- Stream incoming data through pipeline for programmable delay
            mi_pipeline <= mi_pipeline(1 to 7) & spi_miso_i;
            -- Process data on strobe
            if read_bit_strobe then
                -- Shift data into output
                data_mi_o <=
                    data_mi_o(6 downto 0) &
                    mi_pipeline(to_integer(read_delay_i));
            end if;
            data_mi_valid_o <= read_bit_strobe and read_last_bit;
            data_mi_last_o <= read_last_byte;
        end if;
    end process;

    busy_o <= to_std_ulogic(state /= SPI_IDLE);
end;
