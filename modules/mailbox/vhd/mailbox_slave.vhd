-- Implementation of IC2 end-point for mailbox

-- The mailbox is implemented as a 2K byte BRAM which can be read through the
-- register interface.  A mailbox write transaction consists of a 2 byte address
-- followed by data to be written; in this implementation the data is not
-- interpreted and is simply written to sequential locations in memory.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.mailbox_register_defines.all;

entity mailbox_slave is
    generic (
        MB_ADDRESS : std_ulogic_vector(6 downto 0);
        SLOT_ADDRESS : natural;
        LOG_MSG_COUNT : natural;
        LOG_MSG_LENGTH : natural
    );
    port (
        clk_i : in std_ulogic;

        -- Data received from I2C
        rx_data_i : in std_ulogic_vector(7 downto 0);
        rx_start_i : in std_ulogic;
        rx_strobe_i : in std_ulogic;
        rx_accept_o : out std_ulogic := '0';
        rx_ack_o : out std_ulogic := '0';

        -- Data out to I2C
        tx_data_o : out std_ulogic_vector(7 downto 0);
        tx_ack_o : out std_ulogic := '0';
        tx_strobe_i : in std_ulogic;

        -- End of I2C transaction
        i2c_stop_i : in std_ulogic;

        -- Register access to I2C memory
        write_strobe_i : in std_ulogic;
        write_data_i : in reg_data_t;
        write_ack_o : out std_ulogic;
        read_strobe_i : in std_ulogic;
        read_data_o : out reg_data_t;
        read_ack_o : out std_ulogic := '0';

        -- Slot number decoded during write
        slot_o : out unsigned(3 downto 0)
    );
end;

architecture arch of mailbox_slave is
    -- Access address for mailbox
    type i2c_state_t is (I2C_IDLE, I2C_MSG_ADDR, I2C_DATA);
    signal i2c_state : i2c_state_t := I2C_IDLE;

    constant ADDRESS_BITS : natural := LOG_MSG_COUNT + LOG_MSG_LENGTH;
    signal i2c_message_address : unsigned(LOG_MSG_COUNT-1 downto 0);
    signal i2c_byte_address : unsigned(LOG_MSG_LENGTH-1 downto 0);
    signal i2c_address : unsigned(ADDRESS_BITS-1 downto 0);
    signal i2c_write_strobe : std_ulogic;

    signal register_address : unsigned(ADDRESS_BITS-1 downto 0);
    signal register_write_data : std_ulogic_vector(7 downto 0);
    signal register_write_strobe : std_ulogic := '0';
    signal register_read_data : std_ulogic_vector(7 downto 0);

begin
    i2c_address <= i2c_message_address & i2c_byte_address;
    i2c_write_strobe <=
        rx_strobe_i and not rx_start_i and
        to_std_ulogic(i2c_state = I2C_DATA);

    -- Messages received from MMC
    rx_messages : entity work.memory_array generic map (
        ADDR_BITS => ADDRESS_BITS,
        DATA_BITS => 8
    ) port map (
        clk_i => clk_i,

        read_addr_i => register_address,
        read_data_o => register_read_data,

        write_strobe_i => i2c_write_strobe,
        write_addr_i => i2c_address,
        write_data_i => rx_data_i
    );


    -- Messages ready to send to MMC
    tx_messages : entity work.memory_array generic map (
        ADDR_BITS => ADDRESS_BITS,
        DATA_BITS => 8
    ) port map (
        clk_i => clk_i,

        read_addr_i => i2c_address,
        read_data_o => tx_data_o,

        -- Register writes go directly into TX memory
        write_addr_i => register_address,
        write_data_i => register_write_data,
        write_strobe_i => register_write_strobe
    );


    read_data_o <= (
        MAILBOX_DATA_BITS => register_read_data,
        MAILBOX_SLOT_BITS => std_ulogic_vector(slot_o),
        others => '0');

    write_ack_o <= '1';

    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Register address and strobe
            register_address <=
                unsigned(write_data_i(MAILBOX_MSG_ADDR_BITS)) &
                unsigned(write_data_i(MAILBOX_BYTE_ADDR_BITS));
            register_write_strobe <=
                write_strobe_i and write_data_i(MAILBOX_WRITE_BIT);
            register_write_data <= write_data_i(MAILBOX_DATA_BITS);
            read_ack_o <= read_strobe_i;


            -- Manage I2C state
            if i2c_stop_i then
                -- No further processing after stop seen!
                i2c_state <= I2C_IDLE;
                rx_accept_o <= '0';
            elsif rx_strobe_i then
                if rx_start_i then
                    -- Check that we are being addressed and update state
                    rx_accept_o <=
                        to_std_ulogic(rx_data_i(7 downto 1) = MB_ADDRESS);
                    if rx_data_i(0) = '1' then
                        -- For reads go straight to reading data
                        i2c_state <= I2C_DATA;
                    else
                        -- For writes we need a message address first
                        i2c_state <= I2C_MSG_ADDR;
                    end if;
                elsif i2c_state = I2C_MSG_ADDR then
                    -- Receive message address and check in range
                    i2c_message_address <=
                        unsigned(rx_data_i(LOG_MSG_COUNT-1 downto 0));
                    -- Reject addresses out of range, no high bits set
                    rx_accept_o <= vector_and(
                        not rx_data_i(7 downto LOG_MSG_COUNT));
                    i2c_state <= I2C_DATA;
                end if;
            end if;


            -- Advance byte address: reset when start seen, advance on data read
            -- or write.  This means that repeated reads will always restart
            -- from the start of the message buffer.
            if rx_strobe_i and rx_start_i then
                i2c_byte_address <= (others => '0');
            elsif (rx_strobe_i or tx_strobe_i) and
                  to_std_ulogic(i2c_state = I2C_DATA) then
                i2c_byte_address <= i2c_byte_address + 1;
            end if;

            -- Need one tick to set up rx_accept_o
            rx_ack_o <= rx_strobe_i;
            -- Similarly, one tick to read data to transmit
            tx_ack_o <= tx_strobe_i;


            -- Capture slot write
            if i2c_write_strobe = '1' and i2c_address = SLOT_ADDRESS then
                slot_o <= unsigned(rx_data_i(3 downto 0));
            end if;
        end if;
    end process;
end;
