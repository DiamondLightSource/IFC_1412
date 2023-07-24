-- Control over pin delays

-- Multiplexes selection of the appropriate pin and ensures that the VAR_LOAD
-- procedure for updating and reading delays is properly followed:
--  * First set EN_VTC low for the selected pin
--  * Wait for at least 10 clock ticks
--  * Pulse LOAD high for one clock tick (requires CNTVALUEIN to already
--    be valid on the previous tick; we already require this) if writing
--  * Wait for 10 ticks before restoring EN_VTC
--  * Valid delay is captured after LOAD

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity gddr6_phy_delay_control is
    port (
        clk_i : std_ulogic;

        -- The current delay for the selected pin is returned synchronously
        -- with ack_o.  If write_i is set when strobe_i is pulsed the delay will
        -- be written and any updated delay is returned.
        --   Note that select_i, write_i, the configured delay, and any rx/tx
        -- selection, must be all held unchanged from strobe_i to ack_o
        delay_select_i : in unsigned(6 downto 0);   -- Select pin to act on
        delay_write_i : in std_ulogic;              -- Hold high to write delay
        delay_o : out unsigned(8 downto 0);         -- Delay read from pin
        delay_strobe_i : in std_ulogic;             -- Start read or write
        delay_ack_o : out std_ulogic;               -- Strobed on completion

        enable_vtc_o : out std_ulogic_vector;
        load_delay_o : out std_ulogic_vector;
        read_delay_i : in vector_array(open)(8 downto 0)
    );
end;

architecture arch of gddr6_phy_delay_control is
    type state_t is (IDLE, WAIT_START, WAIT_LOAD);
    signal state : state_t := IDLE;

    signal wait_counter : natural range 0 to 9;
    signal delay_ack_out : std_ulogic := '0';

    signal read_delay_in : read_delay_i'SUBTYPE;
    signal delay_select : natural;
    signal enable_vtc_out : enable_vtc_o'SUBTYPE := (others => '1');
    signal load_delay_out : load_delay_o'SUBTYPE := (others => '0');

begin
    delay_select <= to_integer(delay_select_i);
    process (clk_i) begin
        if rising_edge(clk_i) then
            case state is
                when IDLE => -- Wait for strobe to start processing
                    delay_ack_out <= '0';
                    if delay_strobe_i then
                        -- Start processing by disabling VTC on the selected
                        -- pin.  Now need to wait for 10 ticks
                        enable_vtc_out(delay_select) <= '0';
                        wait_counter <= 9;
                        state <= WAIT_START;
                    else
                        enable_vtc_out <= (others => '1');
                    end if;
                when WAIT_START => -- Wait for counter to expire
                    if wait_counter > 0 then
                        wait_counter <= wait_counter - 1;
                    elsif delay_write_i then
                        load_delay_out(delay_select) <= '1';
                        state <= WAIT_LOAD;
                        wait_counter <= 9;
                    else
                        delay_ack_out <= '1';
                        state <= IDLE;
                    end if;
                when WAIT_LOAD => -- Wait before reasserting VTC
                    load_delay_out <= (others => '0');
                    if wait_counter > 0 then
                        wait_counter <= wait_counter - 1;
                    else
                        delay_ack_out <= '1';
                        state <= IDLE;
                    end if;
            end case;

            -- Register all incoming delays before multiplexing to reduce
            -- routing congestion
            read_delay_in <= read_delay_i;
            if state /= IDLE then
                delay_o <= unsigned(read_delay_in(delay_select));
            end if;
        end if;
    end process;

    enable_vtc_o <= enable_vtc_out;
    load_delay_o <= load_delay_out;
    delay_ack_o <= delay_ack_out;
end;
