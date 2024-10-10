-- Clock crossing FIFO for Write data

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;
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

        -- ctrl_data_ready_i and ctrl_data_advance_i must be asserted for one
        -- tick immediately *before* ctrl_data_o must be consumed, and _ready_i
        -- must be deasserted on the next tick.  If _advance_i is not asserted
        -- the same data will be replayed on the next data cycle.  Timing:
        --
        --  ctrl_clk_i  /   /   /   /   /   /   /   /   /   /
        --                   ___     ___     ___
        --  _ready_i    ____/   \___/   \___/   \____________
        --                           ___     ___
        --  _advance_i  xxxxx___xxxxx   xxxxx   xxxxxxxxxxxxx
        --                       ___ ___ ___ ___ ___ ___
        --  _data_o     xxxxxxxx|_0_|_1_|_0_|_1_|_2_|_3_|xxxx
        --
        -- Note that ctrl_data_o must not be read until a couple of ticks after
        -- the corresponding byte mask is available.
        ctrl_data_o : out ctrl_data_t;
        ctrl_data_advance_i : in std_ulogic;
        ctrl_data_ready_i : in std_ulogic
    );
end;

architecture arch of gddr6_axi_write_data_fifo is
    subtype ADDRESS_RANGE is natural range DATA_FIFO_BITS - 2 downto 0;
    constant EMPTY_BYTE_MASK : std_ulogic_vector(63 downto 0)
        := (others => '0');

    -- Byte mask interface
    --
    -- Write to the byte mask FIFO and advance the data FIFO address when an
    -- valid write advance is received
    signal write_fifo_valid : std_ulogic;
    -- Byte mask associated with the current write
    signal byte_mask_in : std_ulogic_vector(127 downto 0);
    -- This signal should never need to be tested!
    signal write_byte_mask_ready : std_ulogic;
    -- The byte mask can be accumulated over several write cycles
    signal saved_byte_mask : std_ulogic_vector(127 downto 0) := (others => '0');

    -- Data FIFO address control
    signal write_data_address : unsigned(ADDRESS_RANGE);
    signal read_data_address : unsigned(ADDRESS_RANGE);
    signal advance_read_address : std_ulogic;
    signal read_address_valid : std_ulogic;

    -- Data FIFO access
    signal even_write_mask : std_ulogic_vector(31 downto 0);
    signal odd_write_mask : std_ulogic_vector(31 downto 0);
    signal even_write_data : std_ulogic_vector(255 downto 0);
    signal odd_write_data : std_ulogic_vector(255 downto 0);
    signal even_read_data : vector_array(0 to 1)(127 downto 0);
    signal odd_read_data : vector_array(0 to 1)(127 downto 0);

    -- Read control
    signal read_phase : std_ulogic := '0';
    -- Data needs to propagate from read_data_address => {even,odd}_read_data
    -- to ctrl_data_o, for each stage need to keep track of data validity
    signal read_data_valid : std_ulogic := '0'; -- {even,odd}_read_data valid
    -- Tick after data ready
    signal next_data_ready : std_ulogic := '0';

    signal read_data_consumed : std_ulogic;
    signal read_data_strobe : std_ulogic;

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
        FIFO_BITS => DATA_FIFO_BITS - 1,
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


    -- Advance the data read address at the start of a read cycle
    advance_read_address <= ctrl_data_ready_i and ctrl_data_advance_i;

    -- Address management for data FIFO.  We need to separate the address from
    -- the stored data to support the complex two phase update process.
    data_address : entity work.async_fifo_address generic map (
        ADDRESS_WIDTH => DATA_FIFO_BITS - 1,
        ENABLE_WRITE_RESERVE => false,
        ENABLE_READ_RESERVE => false,
        MAX_DELAY => MAX_DELAY
    ) port map (
        write_clk_i => axi_clk_i,
        write_access_i => write_fifo_valid,
        write_ready_o => axi_ready_o,
        write_access_address_o => write_data_address,

        read_clk_i => ctrl_clk_i,
        read_access_i => advance_read_address,
        read_valid_o => read_address_valid,
        read_access_address_o => read_data_address
    );

    -- Dual FIFO buffers.  Channels are distributed among the FIFOs so that bits
    -- 255:0 of the first tick are written to channel 0, 511:256 to channel 1,
    -- bits 255:0 of the second tick are written to channel 2, and 511:256 to
    -- channel 3.
    --
    --              bit 511                             0
    --                  |  11  :  10  :  01  :  00  |    phase = 0
    --  AXI             +------+------+------+------+
    --                  |  31  :  30  :  21  :  30  |    phase = 1
    --
    --                     odd_fifo        even_fifo
    --         wr ph 1 |  30  :  20  |  |  10  |  00  | wr ph 0
    --  FIFO           +------+------+  +------+------+
    --         wr ph 0 |  11  :  01  |  |  31  |  21  | wr ph 1
    --
    --                  ch 3     ch 2     ch 1     ch 0
    --                |  30  | |  20  | |  10  | |  00  |
    --  CTRL          +------+ +------+ +------+ +------+
    --                |  31  | |  21  | |  11  | |  01  |

    even_fifo : entity work.memory_array_dual_bytes generic map (
        ADDR_BITS => DATA_FIFO_BITS,
        DATA_BITS => 256
    ) port map (
        write_clk_i => axi_clk_i,
        write_strobe_i => even_write_mask,
        write_addr_i => write_data_address & axi_write_i.phase,
        write_data_i => even_write_data,

        read_clk_i => ctrl_clk_i,
        read_strobe_i => read_data_strobe,
        read_addr_i => read_data_address & read_phase,
        read_data_o(127 downto 0) => even_read_data(0),
        read_data_o(255 downto 128) => even_read_data(1)
    );

    odd_fifo : entity work.memory_array_dual_bytes generic map (
        ADDR_BITS => DATA_FIFO_BITS,
        DATA_BITS => 256
    ) port map (
        write_clk_i => axi_clk_i,
        write_strobe_i => odd_write_mask,
        write_addr_i => write_data_address & not axi_write_i.phase,
        write_data_i => odd_write_data,

        read_clk_i => ctrl_clk_i,
        read_strobe_i => read_data_strobe,
        read_addr_i => read_data_address & read_phase,
        read_data_o(127 downto 0) => odd_read_data(0),
        read_data_o(255 downto 128) => odd_read_data(1)
    );


    -- Assemble write data and strobes as appropriate
    process (all)
        variable data_out : ctrl_data_t;
        variable mask_out : vector_array(0 to 3)(15 downto 0);
    begin
        data_out := (
            0 => axi_write_i.data(127 downto 0),
            1 => axi_write_i.data(255 downto 128),
            2 => axi_write_i.data(383 downto 256),
            3 => axi_write_i.data(511 downto 384));
        mask_out := (
            0 => axi_write_i.byte_mask(15 downto 0),
            1 => axi_write_i.byte_mask(31 downto 16),
            2 => axi_write_i.byte_mask(47 downto 32),
            3 => axi_write_i.byte_mask(63 downto 48));

        case axi_write_i.phase is
            when '0' =>
                even_write_data <= data_out(2) & data_out(0);
                even_write_mask <= mask_out(2) & mask_out(0);
                odd_write_data  <= data_out(3) & data_out(1);
                odd_write_mask  <= mask_out(3) & mask_out(1);
            when '1' =>
                even_write_data <= data_out(3) & data_out(1);
                even_write_mask <= mask_out(3) & mask_out(1);
                odd_write_data  <= data_out(2) & data_out(0);
                odd_write_mask  <= mask_out(2) & mask_out(0);
            when others =>
        end case;
    end process;


    read_data_consumed <= ctrl_data_ready_i or next_data_ready;
    read_data_strobe <= not read_data_valid or read_data_consumed;

    process (axi_clk_i)
    begin
        if rising_edge(axi_clk_i) then
            if axi_write_i.valid and axi_ready_o then
                -- Accumulate written bytes
                if axi_write_i.advance then
                    saved_byte_mask <= (others => '0');
                else
                    saved_byte_mask <= saved_byte_mask or byte_mask_in;
                end if;
            end if;
        end if;
    end process;


    -- Must not request data when not actually valid!
    process (ctrl_clk_i) begin
        if rising_edge(ctrl_clk_i) then
            -- Can we link read_phase and ctrl_data_ready_i?  Can we ensure they
            -- are always in step?
            assert not advance_read_address or read_phase severity failure;
            -- Ensure that the mask FIFO is never less full than the data FIFO
            assert axi_ready_o or not write_byte_mask_ready
                report "Invalid FIFO state"
                severity failure;

            -- A number of conditions must hold when ctrl_data_ready_i is
            -- asserted
            if ctrl_data_ready_i then
                -- Data must be valid and loaded
                assert read_data_valid severity failure;
                -- Strobes must be separated by at least one tick
                assert not next_data_ready severity failure;
                -- Read phase must be high
                assert read_phase severity failure;
            end if;

            next_data_ready <= ctrl_data_ready_i;

            -- Use _ready_i and _ready_next to determine phase of loaded data
            if ctrl_data_ready_i then
                -- On first tick deliver in direct order
                ctrl_data_o <= even_read_data & odd_read_data;
            elsif next_data_ready then
                -- On second tick swap halves
                ctrl_data_o <= odd_read_data & even_read_data;
            end if;

            -- Toggle phase on successful consumption of data
            if read_data_strobe and read_address_valid then
                read_phase <= not read_phase;
            end if;
            -- Maintain state of read_data_valid
            if read_data_strobe then
                read_data_valid <= read_address_valid;
            end if;
        end if;
    end process;
end;
