-- FIFO for reading data from FLASH

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.register_defs.all;

entity flash_mi_fifo is
    port (
        clk_i : in std_ulogic;

        -- Read interface to user register
        read_strobe_i : in std_ulogic;
        read_data_o : out reg_data_t;
        read_ack_o : out std_ulogic := '0';

        -- Write interface from FLASH
        write_data_i : in std_ulogic_vector(7 downto 0);
        write_valid_i : in std_ulogic;
        -- Strobed on last byte write to ensure last uneven byte is written,
        -- is qualified by write_valid_i
        write_last_i : in std_ulogic;
        -- Strobed before first byte written
        write_reset_i : in std_ulogic
    );
end;

architecture arch of flash_mi_fifo is
    signal word_write_valid : std_ulogic := '0';
    signal word_write_ready : std_ulogic;
    signal word_write_data : reg_data_t;

    signal read_valid : std_ulogic;

    signal byte_counter : natural range 0 to 3 := 0;

    procedure put_byte(
        signal data : inout reg_data_t;
        ix : natural; value : std_ulogic_vector) is
    begin
        data(8*ix + 7 downto 8*ix) <= value;
    end;

begin
    fifo : entity work.fifo generic map (
        FIFO_BITS => 7,         -- Up to 512 bytes = 128 words
        DATA_WIDTH => 32
    ) port map (
        clk_i => clk_i,

        write_valid_i => word_write_valid,
        write_ready_o => word_write_ready,
        write_data_i => word_write_data,

        read_valid_o => read_valid,
        read_ready_i => read_ack_o,     -- See note at end on reading
        read_data_o => read_data_o,

        reset_fifo_i => write_reset_i
    );


    -- Map the 32 bit wide FIFO output onto 8 bit output
    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Catch FIFO errors in simulation only
            assert word_write_ready or not word_write_valid
                report "MI FIFO full when written"
                severity warning;
            assert read_valid or not read_ack_o
                report "MI FIFO empty when read"
                severity warning;

            if write_reset_i then
                byte_counter <= 0;
            elsif write_valid_i then
                put_byte(word_write_data, byte_counter, write_data_i);
                byte_counter <= (byte_counter + 1) mod 4;
            end if;

            word_write_valid <=
                write_valid_i and
                (to_std_ulogic(byte_counter = 3) or write_last_i);

            -- There is a subtle wrinkle to reading the data.  Because reading
            -- the FIFO has a side effect we can only assert read_ack_o directly
            -- in response to read_strobe_i, and to ensure the data read is
            -- valid we use read_ack_o to perform the read.  This is all so that
            -- simple register buffering works (see register_buffer.vhd)
            read_ack_o <= read_strobe_i;
        end if;
    end process;
end;
