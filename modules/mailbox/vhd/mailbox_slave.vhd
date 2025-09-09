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
use work.mailbox_defines.all;

entity mailbox_slave is
    generic (
        MB_ADDRESS : std_ulogic_vector(6 downto 0);
        SLOT_ADDRESS : natural
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

        -- Register access to I2C memory
        write_strobe_i : in std_ulogic;
        write_data_i : in reg_data_t;
        write_ack_o : out std_ulogic := '0';
        read_strobe_i : in std_ulogic;
        read_data_o : out reg_data_t;
        read_ack_o : out std_ulogic;

        -- Slot number decoded during write
        slot_o : out unsigned(3 downto 0)
    );
end;

architecture arch of mailbox_slave is
    -- Interface to memory shared between I2C and register interface
    signal memory_read_address : unsigned(10 downto 0);
    signal memory_read_data : std_ulogic_vector(7 downto 0);
    signal memory_read_strobe : std_ulogic;
    signal memory_read_ack : std_ulogic := '0';
    signal memory_write_address : unsigned(10 downto 0);
    signal memory_write_data : std_ulogic_vector(7 downto 0);
    signal memory_write_strobe : std_ulogic;
    signal memory_write_ack : std_ulogic;

    -- Shared interface for mailbox register access
    signal reg_read_address : unsigned(10 downto 0);
    signal reg_read_data : std_ulogic_vector(7 downto 0);
    signal reg_read_strobe : std_ulogic;
    signal reg_read_ack : std_ulogic;
    signal reg_write_address : unsigned(10 downto 0);
    signal reg_write_data : std_ulogic_vector(7 downto 0);
    signal reg_write_strobe : std_ulogic;
    signal reg_write_ack : std_ulogic;

    -- Shared interface for I2C access
    signal i2c_read_address : unsigned(10 downto 0);
    signal i2c_read_data : std_ulogic_vector(7 downto 0);
    signal i2c_read_strobe : std_ulogic := '0';
    signal i2c_read_ack : std_ulogic;
    signal i2c_write_address : unsigned(10 downto 0);
    signal i2c_write_data : std_ulogic_vector(7 downto 0);
    signal i2c_write_strobe : std_ulogic := '0';
    signal i2c_write_ack : std_ulogic;


    -- Access address for mailbox
    signal i2c_address : unsigned(10 downto 0);
    type i2c_phase_t is (HIGH_ADDR, LOW_ADDR, DATA);
    signal i2c_phase : i2c_phase_t := DATA;

begin
    -- This memory block is multiplexed between reads and writes from I2C and
    -- from the register interface
    memory : entity work.memory_array generic map (
        ADDR_BITS => 11,
        DATA_BITS => 8
    ) port map (
        clk_i => clk_i,

        read_addr_i => memory_read_address,
        read_data_o => memory_read_data,

        write_strobe_i => memory_write_strobe,
        write_addr_i => memory_write_address,
        write_data_i => memory_write_data
    );


    -- Multiplexer to share access to memory
    share : entity work.register_share_rw generic map (
        COUNT => 2,
        ADDRESS_WIDTH => 11,
        DATA_WIDTH => 8
    ) port map (
        clk_i => clk_i,

        mux_read_address_i => (reg_read_address, i2c_read_address),
        mux_read_data_o(0) => reg_read_data,
        mux_read_data_o(1) => i2c_read_data,
        mux_read_strobe_i => (reg_read_strobe, i2c_read_strobe),
        mux_read_ack_o(0) => reg_read_ack,
        mux_read_ack_o(1) => i2c_read_ack,

        mux_write_address_i => (reg_write_address, i2c_write_address),
        mux_write_data_i => (reg_write_data, i2c_write_data),
        mux_write_strobe_i => (reg_write_strobe, i2c_write_strobe),
        mux_write_ack_o(0) => reg_write_ack,
        mux_write_ack_o(1) => i2c_write_ack,

        shared_write_address_o => memory_write_address,
        shared_write_data_o => memory_write_data,
        shared_write_strobe_o => memory_write_strobe,
        shared_write_ack_i => memory_write_ack,
        shared_read_address_o => memory_read_address,
        shared_read_data_i => memory_read_data,
        shared_read_strobe_o => memory_read_strobe,
        shared_read_ack_i => memory_read_ack
    );


    -- We generate a read or write strobe depending on the request and
    -- can use either response as the acknowledgement
    reg_write_strobe <= write_strobe_i and write_data_i(MAILBOX_WRITE_BIT);
    reg_read_strobe <= write_strobe_i and not write_data_i(MAILBOX_WRITE_BIT);
    reg_read_address <= unsigned(write_data_i(MAILBOX_ADDRESS_BITS));
    write_ack_o <= reg_read_ack or reg_write_ack;
    -- For register reading we can simply return the value prepared by an
    -- earlier write with .WRITE = 0, and read_strobe_i is just ignored
    read_ack_o <= '1';

    -- Can plumb register request directly in
    reg_write_address <= unsigned(write_data_i(MAILBOX_ADDRESS_BITS));
    reg_write_data <= write_data_i(MAILBOX_DATA_BITS);
    read_data_o <= (
        MAILBOX_DATA_BITS => reg_read_data,
        MAILBOX_SLOT_BITS => std_ulogic_vector(slot_o),
        others => '0');

    tx_data_o <= i2c_read_data;
    tx_ack_o <= i2c_read_ack;

    -- This can be unconditionally acknowledged, we'll need a one tick delay on
    -- the read strobe acknowledge
    memory_write_ack <= '1';


    process (clk_i) begin
        if rising_edge(clk_i) then
            memory_read_ack <= memory_read_strobe;

            -- Default settings
            i2c_write_strobe <= '0';
            i2c_read_strobe <= '0';

            if rx_strobe_i then
                if rx_start_i then
                    rx_accept_o <=
                        to_std_ulogic(rx_data_i(7 downto 1) = MB_ADDRESS);
                    if rx_data_i(0) = '1' then
                        i2c_phase <= DATA;
                    else
                        i2c_phase <= HIGH_ADDR;
                    end if;
                else
                    case i2c_phase is
                        when HIGH_ADDR =>
                            -- Reject writes to high addresses
                            i2c_address(10 downto 8) <=
                                unsigned(rx_data_i(2 downto 0));
                            rx_accept_o <= to_std_ulogic(
                                rx_data_i(7 downto 3) = 5X"00");
                            i2c_phase <= LOW_ADDR;
                        when LOW_ADDR =>
                            i2c_address(7 downto 0) <= unsigned(rx_data_i);
                            i2c_phase <= DATA;
                            rx_accept_o <= '1';
                        when DATA =>
                            i2c_write_address <= i2c_address;
                            i2c_write_data <= rx_data_i;
                            i2c_write_strobe <= '1';
                            i2c_address <= i2c_address + 1;
                            rx_accept_o <= '1';
                    end case;
                end if;
            elsif tx_strobe_i then
                i2c_read_address <= i2c_address;
                i2c_read_strobe <= '1';
                i2c_address <= i2c_address + 1;
            end if;
            rx_ack_o <= rx_strobe_i;

            -- Capture slot write
            if i2c_write_strobe = '1' and i2c_write_address = SLOT_ADDRESS then
                slot_o <= unsigned(i2c_write_data(3 downto 0));
            end if;
        end if;
    end process;
end;
