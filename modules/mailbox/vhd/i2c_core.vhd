-- IC2 core

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity i2c_core is
    port (
        clk_i : in std_ulogic;

        -- I2C bus: _i from bus, _o out
        scl_i : in std_ulogic;
        sda_i : in std_ulogic;
        sda_o : out std_ulogic := '1';

        -- Received data is signalled by strobing rx_strobe_o which must be
        -- acknowleged in a timely way by strobing rx_ack_i.  rx_ack_i must only
        -- be set high in response to rx_strobe_o.
        rx_data_o : out std_ulogic_vector(7 downto 0);
        -- Set on first byte received: in this case rx_data_o is the requested
        -- I2C address (plus the bottom read/write* bit)
        rx_start_o : out std_ulogic;
        -- Set at the same time as rx_start_o if this is a restart.  This is
        -- only likely to be useful for implementing a 10-bit read address.
        rx_restart_o : out std_ulogic;
        -- accept is only valid when ready is asserted, if not set then incoming
        -- data will not be acknowledged.
        rx_accept_i : in std_ulogic;
        -- Strobe to request processing of received data, ack on completion
        rx_strobe_o : out std_ulogic := '0';
        rx_ack_i : in std_ulogic;

        -- Data to transmit, requested by tx_strobe_o shortly after address or
        -- data has been acknowledged.
        tx_data_i : in std_ulogic_vector(7 downto 0);
        tx_strobe_o : out std_ulogic := '0';
        tx_ack_i : in std_ulogic;

        stop_o : out std_ulogic := '0'
    );
end;

architecture arch of i2c_core is
    -- Events decoded from incoming stream
    signal start : std_ulogic;
    signal stop : std_ulogic;
    signal data_valid : std_ulogic;
    signal data_bit : std_ulogic;

    -- State machine for managing communication
    --
    --  IDLE --> STARTING
    --             | on data_valid
    --             |
    --             v     on last bit              on rx_ack_i
    --          RECEIVE --------------> WAIT RX --------------> WAIT RX --.
    --             ^    set rx_strobe_o  READY                    ACK     |
    --     RW* = 0 |                             on ACK                   |
    --             +------------------------------------------------------.
    --     RW* = 1 | set tx_strobe_o
    --             |
    --             v    on tx_ack_i             on last bit
    --          WAIT TX --------------> TRANSMIT -------------> WAIT TX --.
    --           READY                                            ACK     |
    --             |                             on ACK                   |
    --             .------------------------------------------------------.
    --
    -- Transitions to IDLE are triggered by NAK and stop.
    type state_t is (
        IDLE,               -- Nothing in progress
        STARTING,           -- START seen, waiting for start of address
        RECEIVE,            -- Receiving, one bit at a time
        WAIT_RX_READY,      -- Waiting for rx_strobe_o response
        WAIT_RX_ACK,        -- Waiting for completion of ack after RX
        TRANSMIT,           -- Transmitting, one bit at a time
        WAIT_TX_READY,      -- Waiting for next byte to send
        WAIT_TX_ACK         -- Waiting for completion of ack after TX
    );
    signal state : state_t := IDLE;

    -- Set while receiving address byte
    signal receive_address : std_ulogic;
    -- Set on completion of received address to determine direction
    signal read_write_n : std_ulogic;
    signal bit_counter : natural range 0 to 7;
    -- Data to send
    signal tx_data_in : std_ulogic_vector(7 downto 0) := X"FF";
    -- Used to detect restart
    signal stop_seen : std_ulogic := '1';

begin
    -- Clean up the IC2 signals and decode into raw start/stop/data_valid events
    signals : entity work.i2c_signals port map (
        clk_i => clk_i,

        scl_i => scl_i,
        sda_i => sda_i,

        start_o => start,
        stop_o => stop,
        data_valid_o => data_valid,
        data_bit_o => data_bit
    );

    -- Let clients see the unfiltered stop events
    stop_o <= stop;

    process (clk_i)
        procedure reset_outputs is
        begin
            sda_o <= '1';
            rx_strobe_o <= '0';
            tx_strobe_o <= '0';
        end;

        procedure start_receive is
        begin
            sda_o <= '1';
            bit_counter <= 7;
            state <= RECEIVE;
        end;

        procedure receive_bit is
        begin
            rx_data_o(bit_counter) <= data_bit;
            if bit_counter > 0 then
                bit_counter <= bit_counter - 1;
            else
                -- On the last bit push the received byte up and wait for ack.
                rx_start_o <= receive_address;
                if receive_address then
                    read_write_n <= data_bit;
                end if;
                receive_address <= '0';
                rx_strobe_o <= '1';
                state <= WAIT_RX_READY;
            end if;
        end;

        procedure handle_rx_ready is
        begin
            sda_o <= not rx_accept_i;
            if rx_accept_i then
                state <= WAIT_RX_ACK;
            else
                -- If we're not accepting this write then we're done and can
                -- safely go idle.
                state <= IDLE;
            end if;
        end;

        procedure request_transmit_data is
        begin
            tx_strobe_o <= '1';
            state <= WAIT_TX_READY;
        end;

        procedure start_transmit is
        begin
            -- Last bit is high to leave SDA idle to receive ACK bit
            tx_data_in <= tx_data_i(6 downto 0) & '1';
            sda_o <= tx_data_i(7);
            bit_counter <= 7;
            state <= TRANSMIT;
        end;

        procedure transmit_bit is
        begin
            sda_o <= tx_data_in(bit_counter);
            if bit_counter > 0 then
                bit_counter <= bit_counter - 1;
            else
                state <= WAIT_TX_ACK;
            end if;
        end;

        procedure handle_tx_ack is
        begin
            if data_bit = '0' then
                -- Continue with transmission on successful ACK
                request_transmit_data;
            else
                state <= IDLE;
            end if;
        end;

    begin
        if rising_edge(clk_i) then
            -- Handle start and stop conditions outside of the normal state
            -- machine as these can occur at almost any state
            if start then
                -- We're supposed to accept a start at any time!
                -- Keep track of restarts
                rx_restart_o <= not stop_seen;
                stop_seen <= '0';
                reset_outputs;
                receive_address <= '1';
                state <= STARTING;
            elsif stop then
                stop_seen <= '1';
                reset_outputs;
                state <= IDLE;
            else
                case state is
                    when IDLE =>
                    when STARTING =>
                        if data_valid then
                            start_receive;
                        end if;
                    when RECEIVE =>
                        if data_valid then
                            receive_bit;
                        end if;
                    when WAIT_RX_READY =>
                        rx_strobe_o <= '0';
                        if rx_ack_i then
                            handle_rx_ready;
                        end if;
                    when WAIT_RX_ACK =>
                        if data_valid then
                            if read_write_n then
                                request_transmit_data;
                            else
                                start_receive;
                            end if;
                        end if;
                    when WAIT_TX_READY =>
                        tx_strobe_o <= '0';
                        if tx_ack_i then
                            start_transmit;
                        end if;
                    when TRANSMIT =>
                        if data_valid then
                            transmit_bit;
                        end if;
                    when WAIT_TX_ACK =>
                        if data_valid then
                            handle_tx_ack;
                        end if;
                end case;
            end if;
        end if;
    end process;
end;
