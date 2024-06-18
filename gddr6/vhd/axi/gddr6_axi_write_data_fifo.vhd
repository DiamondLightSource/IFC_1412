-- Clock crossing FIFO for Write data

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.gddr6_axi_defs.all;

entity gddr6_axi_write_data_fifo is
    generic (
        FIFO_BITS : natural := 10
    );
    port (
        -- AXI interface
        axi_clk_i : in std_ulogic;

        -- Data interface
        axi_write_i : in write_data_t;
        axi_ready_o : out std_ulogic := '0';

        -- CTRL interface
        ctrl_clk_i : in std_ulogic;

        -- Reading byte mask
        ctrl_byte_mask_o : out std_logic_vector(127 downto 0);
        ctrl_byte_mask_valid_o : out std_ulogic := '0';
        ctrl_byte_mask_ready_i : in std_ulogic;
        -- Reading data to be written.  ctrl_data_o will be loaded one tick
        -- after ctrl_data_ready_i is strobed, and ctrl_data_advance_i
        -- determines whether the fifo is advanced (this is held low to resend
        -- the same data when doing multiple partial writes).
        ctrl_data_o : out vector_array(0 to 3)(127 downto 0);
        ctrl_data_advance_i : in std_ulogic;
        ctrl_data_ready_i : in std_ulogic
    );
end;

architecture arch of gddr6_axi_write_data_fifo is
    signal write_address : unsigned(FIFO_BITS-2 downto 0);
    signal data_read_address : unsigned(FIFO_BITS-2 downto 0);
    signal byte_mask_read_address : unsigned(FIFO_BITS-2 downto 0);
    signal read_phase : std_ulogic := '0';

    -- The byte mask can be accumulated over several write cycles
    signal saved_byte_mask : std_ulogic_vector(127 downto 0) := (others => '0');

    signal write_valid : std_ulogic;
    signal read_byte_mask_enable : std_ulogic;
    signal read_byte_mask_valid : std_ulogic;

    -- Three separate FIFO buffers: one for the byte mask, and two separate
    -- FIFOs to support data interleaving
    subtype SG_FIFO_RANGE is natural range 0 to 2**(FIFO_BITS-1) - 1;
    subtype DATA_FIFO_RANGE is natural range 0 to 2**FIFO_BITS - 1;
    signal byte_mask_fifo : vector_array(SG_FIFO_RANGE)(127 downto 0);
    signal even_data_fifo : vector_array(DATA_FIFO_RANGE)(255 downto 0);
    signal odd_data_fifo  : vector_array(DATA_FIFO_RANGE)(255 downto 0);

begin
    -- The clock domain crossing part of this FIFO works in steps of SG bursts
    async_address : entity work.async_fifo_address generic map (
        ADDRESS_WIDTH => FIFO_BITS - 1,
        ENABLE_WRITE_RESERVE => false,
        ENABLE_READ_RESERVE => true
    ) port map (
        write_clk_i => axi_clk_i,
        write_access_i => write_valid,
        write_ready_o => axi_ready_o,
        write_access_address_o => write_address,

        read_clk_i => ctrl_clk_i,
        read_reserve_i => read_byte_mask_enable,
        read_ready_o => read_byte_mask_valid,
        read_reserve_address_o => byte_mask_read_address,
        read_access_i => ctrl_data_advance_i and ctrl_data_ready_i,
        read_access_address_o => data_read_address
    );
    write_valid <= axi_write_i.valid and axi_ready_o and axi_write_i.advance;
    read_byte_mask_enable <=
        read_byte_mask_valid and
        (ctrl_byte_mask_ready_i or not ctrl_byte_mask_valid_o);


    process (axi_clk_i)
        procedure write_byte(
            signal fifo : inout vector_array; phase : std_ulogic;
            fifo_byte : natural; data_byte : natural)
        is
            variable address : natural;
        begin
            address := to_integer(write_address & phase);
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

        constant EMPTY_BYTE_MASK : std_ulogic_vector(63 downto 0)
            := (others => '0');
        variable byte_mask_in : std_ulogic_vector(127 downto 0);

    begin
        if rising_edge(axi_clk_i) then
            if axi_write_i.valid and axi_ready_o then
                case axi_write_i.phase is
                    when '0' =>
                        distribute_writes(even_data_fifo, odd_data_fifo);
                        byte_mask_in := EMPTY_BYTE_MASK & axi_write_i.byte_mask;
                    when '1' =>
                        distribute_writes(odd_data_fifo, even_data_fifo);
                        byte_mask_in := axi_write_i.byte_mask & EMPTY_BYTE_MASK;
                    when others =>
                end case;

                if axi_write_i.advance then
                    byte_mask_fifo(to_integer(write_address)) <=
                        byte_mask_in or saved_byte_mask;
                    saved_byte_mask <= (others => '0');
                else
                    saved_byte_mask <= saved_byte_mask or byte_mask_in;
                end if;
            end if;
        end if;
    end process;


    process (ctrl_clk_i)
        variable address : natural;
    begin
        if rising_edge(ctrl_clk_i) then
            if ctrl_data_ready_i then
                address := to_integer(data_read_address & read_phase);
                case read_phase is
                    when '0' =>
                        ctrl_data_o <= (
                            0 => even_data_fifo(address)(127 downto 0),
                            1 => even_data_fifo(address)(255 downto 128),
                            2 => odd_data_fifo(address)(127 downto 0),
                            3 => odd_data_fifo(address)(255 downto 128)
                        );
                    when '1' =>
                        ctrl_data_o <= (
                            0 => odd_data_fifo(address)(127 downto 0),
                            1 => odd_data_fifo(address)(255 downto 128),
                            2 => even_data_fifo(address)(127 downto 0),
                            3 => even_data_fifo(address)(255 downto 128)
                        );
                    when others =>
                end case;
                read_phase <= not read_phase;
            end if;

            if read_byte_mask_enable then
                ctrl_byte_mask_o <=
                    byte_mask_fifo(to_integer(byte_mask_read_address));
                ctrl_byte_mask_valid_o <= '1';
            elsif ctrl_byte_mask_ready_i then
                ctrl_byte_mask_valid_o <= '0';
            end if;
        end if;
    end process;
end;
