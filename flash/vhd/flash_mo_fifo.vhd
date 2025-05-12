-- FIFO for writing data to FLASH

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.register_defs.all;

entity flash_mo_fifo is
    generic (
        constant FIFO_BITS : natural
    );
    port (
        clk_i : in std_ulogic;

        -- Write interface from user registers
        write_strobe_i : in std_ulogic;
        write_data_i : in reg_data_t;
        write_ack_o : out std_ulogic := '0';

        -- Read interface to FLASH
        read_data_o : out std_ulogic_vector(7 downto 0);
        read_ready_i : in std_ulogic;
        -- This is strobed at the end of the read transaction after reading the
        -- last byte
        read_reset_i : in std_ulogic
    );
end;

architecture arch of flash_mo_fifo is
    signal ack_pending : std_ulogic := '0';
    signal write_ready : std_ulogic;

    signal advance_byte : std_ulogic;
    signal advance_word : std_ulogic;

    signal word_read_valid : std_ulogic;
    signal word_read_data : reg_data_t;

    signal byte_counter : natural range 0 to 3 := 0;
    signal byte_read_valid : std_ulogic := '0';

    function get_byte(data : reg_data_t; ix : natural)
        return std_ulogic_vector is
    begin
        return data(8*ix + 7 downto 8*ix);
    end;

begin
    -- We need to know whether to advance to the next byte and the next word as
    -- a combinatorial calculation (well not really, we never actually have
    -- back to back reads, but this is better style).
    advance_byte <= not byte_read_valid or read_ready_i;
    advance_word <= not word_read_valid or
        (advance_byte and to_std_ulogic(byte_counter = 3));


    fifo : entity work.fifo generic map (
        FIFO_BITS => FIFO_BITS,
        DATA_WIDTH => 32
    ) port map (
        clk_i => clk_i,

        write_valid_i => write_strobe_i,
        write_ready_o => write_ready,
        write_data_i => write_data_i,

        read_valid_o => word_read_valid,
        read_ready_i => advance_word,
        read_data_o => word_read_data,

        reset_fifo_i => read_reset_i
    );


    -- Map the 32 bit wide FIFO output onto 8 bit output
    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Acknowledge once the write has appeared at the output, ensure we
            -- don't get stuck if a reset happens
            if read_reset_i or byte_read_valid then
                write_ack_o <= ack_pending or write_strobe_i;
                ack_pending <= '0';
            else
                ack_pending <= ack_pending or write_strobe_i;
            end if;

            -- We don't bother to check whether the FIFO is full.  As it
            -- happens we get away with this because when the FIFO is not ready
            -- it simply ignores extra writes!  Catch this in simulation.
            assert write_ready or not write_strobe_i
                report "MO FIFO full when written"
                severity warning;
            -- Similarly we don't check that reads are valid; if the user didn't
            -- fill the FIFO then that's just too bad
            assert byte_read_valid or not read_ready_i
                report "MO FIFO empty when read"
                severity warning;

            if read_reset_i then
                byte_counter <= 0;
                byte_read_valid <= '0';
            elsif advance_byte and word_read_valid then
                read_data_o <= get_byte(word_read_data, byte_counter);
                byte_counter <= (byte_counter + 1) mod 4;
                byte_read_valid <= '1';
            elsif read_ready_i then
                byte_read_valid <= '0';
            end if;
        end if;
    end process;
end;
