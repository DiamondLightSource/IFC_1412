-- Clock crossing FIFO for Write data

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.gddr6_axi_defs.all;

entity gddr6_axi_write_data_fifo is
    generic (
        DATA_FIFO_BITS : natural;
        MAX_DELAY : real
    );
    port (
        -- AXI interface
        axi_clk_i : in std_ulogic;

        -- Data interface
        axi_write_i : in write_data_t;
        axi_ready_o : out std_ulogic := '0';

        -- CTRL interface
        ctrl_clk_i : in std_ulogic;

        -- Reading byte mask.  Each byte mask read must be followed by a
        -- corresponding read of two data values at some point later.
        ctrl_byte_mask_o : out std_logic_vector(127 downto 0);
        ctrl_byte_mask_valid_o : out std_ulogic := '0';
        ctrl_byte_mask_ready_i : in std_ulogic;

        -- ctrl_data_o will be valid as soon as the corresponding byte mask is
        -- available, and must not be read before.  If ctrl_data_advance_i is
        -- not set while ctrl_data_ready_i is asserted the data will be
        -- replayed: this is designed to be used with separate writes to
        -- multiple channels.
        ctrl_data_o : out vector_array(0 to 3)(127 downto 0);
        ctrl_data_advance_i : in std_ulogic;
        ctrl_data_ready_i : in std_ulogic
    );
end;

architecture arch of gddr6_axi_write_data_fifo is
    signal write_data_address : unsigned(DATA_FIFO_BITS-1 downto 0);
    signal read_data_address : unsigned(DATA_FIFO_BITS-1 downto 0);

    signal write_fifo_valid : std_ulogic;
    signal write_byte_mask_ready : std_ulogic;

    signal read_phase : std_ulogic := '0';
    signal read_data_valid : std_ulogic;
    signal data_valid : std_ulogic := '0';

    -- The byte mask can be accumulated over several write cycles
    signal saved_byte_mask : std_ulogic_vector(127 downto 0) := (others => '0');

    -- Three separate FIFO buffers: one for the byte mask, and two separate
    -- FIFOs to support data interleaving
    subtype DATA_FIFO_RANGE is natural range 0 to 2**DATA_FIFO_BITS - 1;
    signal even_data_fifo : vector_array(DATA_FIFO_RANGE)(255 downto 0);
    signal odd_data_fifo  : vector_array(DATA_FIFO_RANGE)(255 downto 0);

    -- Byte mask associated with the current write
    constant EMPTY_BYTE_MASK : std_ulogic_vector(63 downto 0)
        := (others => '0');
    signal byte_mask_in : std_ulogic_vector(127 downto 0);

begin
    -- Advance writes to both FIFOs on the same tick
    write_fifo_valid <=
        axi_write_i.valid and axi_ready_o and axi_write_i.advance;

    -- Shift the incoming byte mask according to the write phase
    with axi_write_i.phase select
        byte_mask_in <=
            EMPTY_BYTE_MASK & axi_write_i.byte_mask when '0',
            axi_write_i.byte_mask & EMPTY_BYTE_MASK when '1',
            (others => '0') when others;

    -- FIFO for byte mask.  This will always have no more entries than the data
    -- FIFO: we write to this FIFO when advancing the data FIFO pointer, and
    -- data is never read without first reading the associated byte mask.
    mask_fifo : entity work.async_fifo generic map (
        FIFO_BITS => DATA_FIFO_BITS,
        DATA_WIDTH => 128,
        MAX_DELAY => MAX_DELAY
    ) port map (
        write_clk_i => axi_clk_i,
        write_valid_i => write_fifo_valid,
        write_ready_o => write_byte_mask_ready,
        write_data_i => byte_mask_in or saved_byte_mask,

        read_clk_i => ctrl_clk_i,
        read_valid_o => ctrl_byte_mask_valid_o,
        read_ready_i => ctrl_byte_mask_ready_i,
        read_data_o => ctrl_byte_mask_o
    );

    -- Address management for data FIFO.  We need to separate the address from
    -- the stored data to support the complex two phase update process.
    data_address : entity work.async_fifo_address generic map (
        ADDRESS_WIDTH => DATA_FIFO_BITS,
        ENABLE_WRITE_RESERVE => false,
        ENABLE_READ_RESERVE => false,
        MAX_DELAY => MAX_DELAY
    ) port map (
        write_clk_i => axi_clk_i,
        write_access_i => write_fifo_valid,
        write_ready_o => axi_ready_o,
        write_access_address_o => write_data_address,

        read_clk_i => ctrl_clk_i,
        read_access_i =>
            ctrl_data_ready_i and read_phase and ctrl_data_advance_i,
        read_valid_o => read_data_valid,
        read_access_address_o => read_data_address
    );


    -- Ensure that the mask FIFO is never less full than the data FIFO
    assert axi_ready_o or not write_byte_mask_ready
        report "Invalid FIFO state"
        severity failure;


    process (axi_clk_i)
        procedure write_byte(
            signal fifo : inout vector_array; phase : std_ulogic;
            fifo_byte : natural; data_byte : natural)
        is
            variable address : natural;
        begin
            address := to_integer(write_data_address & phase);
            if axi_write_i.byte_mask(data_byte) then
                fifo(address)(8*fifo_byte + 7 downto 8*fifo_byte) <=
                    axi_write_i.data(8*data_byte + 7 downto 8*data_byte);
            end if;
        end;

        -- Distribute byte writes to the odd and even FIFOs according to phase
        procedure distribute_writes(
            signal first_fifo : inout vector_array;
            signal second_fifo : inout vector_array) is
        begin
            for byte in 0 to 63 loop
                if 0 <= byte and byte < 16 then
                    write_byte(first_fifo, '0', byte, byte);
                elsif 16 <= byte and byte < 32 then
                    write_byte(second_fifo, '1', byte - 16, byte);
                elsif 32 <= byte and byte < 48 then
                    write_byte(first_fifo, '0', byte - 16, byte);
                elsif 48 <= byte and byte < 64 then
                    write_byte(second_fifo, '1', byte - 32, byte);
                end if;
            end loop;
        end;

    begin
        if rising_edge(axi_clk_i) then
            if axi_write_i.valid and axi_ready_o then
                case axi_write_i.phase is
                    when '0' =>
                        distribute_writes(even_data_fifo, odd_data_fifo);
                    when '1' =>
                        distribute_writes(odd_data_fifo, even_data_fifo);
                    when others =>
                end case;

                if axi_write_i.advance then
                    saved_byte_mask <= (others => '0');
                else
                    saved_byte_mask <= saved_byte_mask or byte_mask_in;
                end if;
            end if;
        end if;
    end process;


    -- Must not request data when not actually valid!
    process (ctrl_clk_i)
        subtype LOWER_HALF is natural range 127 downto 0;
        subtype UPPER_HALF is natural range 255 downto 128;
        variable address : natural;
    begin
        if rising_edge(ctrl_clk_i) then
            assert data_valid or not ctrl_data_ready_i severity failure;

            if ctrl_data_ready_i or not data_valid then
                address := to_integer(read_data_address & read_phase);
                case read_phase is
                    when '0' =>
                        ctrl_data_o <= (
                            0 => even_data_fifo(address)(LOWER_HALF),
                            1 => even_data_fifo(address)(UPPER_HALF),
                            2 => odd_data_fifo(address)(LOWER_HALF),
                            3 => odd_data_fifo(address)(UPPER_HALF)
                        );
                    when '1' =>
                        ctrl_data_o <= (
                            0 => odd_data_fifo(address)(LOWER_HALF),
                            1 => odd_data_fifo(address)(UPPER_HALF),
                            2 => even_data_fifo(address)(LOWER_HALF),
                            3 => even_data_fifo(address)(UPPER_HALF)
                        );
                    when others =>
                end case;

                -- There is valid data in the buffer whenever the byte mask
                -- buffer is ready, and this test is early enough for us.
                data_valid <= read_data_valid;
                if read_data_valid then
                    read_phase <= not read_phase;
                end if;
            end if;
        end if;
    end process;
end;
