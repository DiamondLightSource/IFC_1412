-- Send and receive data for AXI transaction

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;

use work.gddr6_defs.all;

entity axi_data is
    port (
        clk_i : in std_ulogic;

        -- Data register interface
        write_strobe_i : in std_ulogic;
        write_data_i : in reg_data_t;
        write_ack_o : out std_ulogic := '0';
        read_strobe_i : in std_ulogic;
        read_data_o : out reg_data_t;
        read_ack_o : out std_ulogic;

        -- Register read/write control
        start_read_i : in std_ulogic;       -- Resets column and address
        step_read_i : in std_ulogic;        -- Advance read row
        start_write_i : in std_ulogic;      -- Also resets AXI transmit buffer
        step_write_i : in std_ulogic;       -- Advance write row and increment

        write_mask_i : in std_ulogic_vector(3 downto 0);

        -- AXI control
        axi_out_start_i : in std_ulogic;    -- Initiate AXI output
        axi_in_start_i : in std_ulogic;     -- Initiate AXI read
        -- Status information
        axi_out_busy_o : out std_ulogic;
        axi_in_busy_o : out std_ulogic;
        axi_out_ok_o : out std_ulogic := '0';
        axi_in_ok_o : out std_ulogic := '0';
        -- Read and write counters
        axi_out_count_o : out unsigned(5 downto 0);
        axi_in_count_o : out unsigned(5 downto 0);

        -- Read/Write data from/to AXI
        axi_out_o : out axi_write_data_t := IDLE_AXI_WRITE_DATA;
        axi_out_ready_i : in std_ulogic;
        axi_out_response_i : in axi_write_response_t;
        axi_out_response_ready_o : out std_ulogic := '0';
        axi_in_i : in axi_read_data_t;
        axi_in_ready_o : out std_ulogic := '0'
    );
end;

architecture arch of axi_data is
    -- The read and write addresses are one bit wider than immediately necessary
    -- to distinguish between full and empty
    signal reg_write_address : unsigned(5 downto 0) := (others => '0');
    signal reg_write_column : natural range 0 to 15 := 0;
    signal reg_read_address : unsigned(5 downto 0) := (others => '0');
    signal reg_read_column : natural range 0 to 15 := 0;
    signal reset_byte_mask : std_ulogic := '0';

    signal axi_in_address : unsigned(5 downto 0) := (others => '0');
    signal axi_out_address : unsigned(5 downto 0) := (others => '0');
    signal next_axi_out_address : unsigned(5 downto 0);
    signal axi_out_busy : std_ulogic := '0';
    signal axi_out_data_taken : std_ulogic;
    signal axi_out_strobe : std_ulogic;
    signal last_data_out : std_ulogic;

    signal write_word_strobe : std_ulogic_vector(0 to 15);
    signal read_data : reg_data_array_t(0 to 15);

begin
    gen_words : for word in 0 to 15 generate
        subtype WORD_RANGE is natural range 32*word + 31 downto 32*word;
        subtype MASK_RANGE is natural range 4*word + 3 downto 4*word;
    begin
        to_axi : entity work.memory_array generic map (
            ADDR_BITS => 6,
            DATA_BITS => 32
        ) port map (
            clk_i => clk_i,

            write_strobe_i => write_word_strobe(word),
            write_addr_i => reg_write_address,
            write_data_i => write_data_i,

            read_strobe_i => axi_out_strobe,
            read_addr_i => axi_out_address,
            read_data_o => axi_out_o.data(WORD_RANGE)
        );

        write_strobes : entity work.memory_array generic map (
            ADDR_BITS => 6,
            DATA_BITS => 4
        ) port map (
            clk_i => clk_i,

            write_strobe_i => write_word_strobe(word) or reset_byte_mask,
            write_addr_i => reg_write_address,
            write_data_i => write_mask_i and not reset_byte_mask,

            read_strobe_i => axi_out_strobe,
            read_addr_i => axi_out_address,
            read_data_o => axi_out_o.strb(MASK_RANGE)
        );

        from_axi : entity work.memory_array generic map (
            ADDR_BITS => 6,
            DATA_BITS => 32
        ) port map (
            clk_i => clk_i,

            write_strobe_i => axi_in_i.valid and axi_in_ready_o,
            write_addr_i => axi_in_address,
            write_data_i => axi_in_i.data(WORD_RANGE),

            read_addr_i => reg_read_address,
            read_data_o => read_data(word)
        );
    end generate;


    -- Writes can be processed and acknowledged immediately
    write_ack_o <= '1';
    compute_strobe(write_word_strobe, reg_write_column, write_strobe_i);

    -- Advance the output buffer during startup and when data is taken
    axi_out_data_taken <= axi_out_o.valid and axi_out_ready_i;
    axi_out_strobe <=
        (axi_out_busy and not axi_out_o.valid) or   -- Initial priming state
        axi_out_data_taken;
    -- This is meant to be simply
    --     last_data_out <= axi_out_address + 1 ?= reg_write_address;
    -- but unfortunately this form triggers some very strange Vivado bugs
    next_axi_out_address <= axi_out_address + 1;
    last_data_out <= to_std_ulogic(next_axi_out_address = reg_write_address);

    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Register writes
            if start_write_i then
                reg_write_address <= (others => '0');
                reg_write_column <= 0;
            elsif step_write_i then
                reg_write_address <= reg_write_address + 1;
                reg_write_column <= 0;
            elsif write_strobe_i then
                reg_write_column <= reg_write_column + 1;
            end if;
            -- Trigger a special reset cycle on start/step of write.  This works
            -- so long as we don't try to write on the tick immediately after
            -- start or step
            reset_byte_mask <= start_write_i or step_write_i;

            -- Register reads
            if start_read_i then
                reg_read_address <= (others => '0');
                reg_read_column <= 0;
            elsif step_read_i then
                reg_read_address <= reg_read_address + 1;
                reg_read_column <= 0;
            elsif read_strobe_i then
                reg_read_column <= reg_read_column + 1;
            end if;
            read_data_o <= read_data(reg_read_column);
            read_ack_o <= read_strobe_i;


            -- AXI reads.  When enabled fill memory until last encountered
            if axi_in_start_i then
                axi_in_address <= (others => '0');
                axi_in_ready_o <= '1';
                axi_in_ok_o <= '1';
            elsif axi_in_i.valid then
                axi_in_address <= axi_in_address + 1;
                if axi_in_i.last then
                    axi_in_ready_o <= '0';
                end if;
                axi_in_ok_o <= axi_in_ok_o and axi_in_i.resp ?= "00";
            end if;


            -- AXI writes.
            -- The state machine here is a bit tricky because there is a one
            -- tick lag from presenting the address to receiving the data.  This
            -- means we end up cycling through four states determined by the
            -- combination (axi_out_busy,axi_out_o.valid):
            --  (0,0)   idle, start reading on axi_out_start_i
            --  (1,0)   one tick transition state to prime buffers before valid
            --  (1,1)   normal transfer state, advance data on axi_out_ready_i
            --  (0,1)   runout state to complete final transfer
            if axi_out_busy then
                -- During normal operation advance on data strobe
                if axi_out_strobe then
                    axi_out_address <= axi_out_address + 1;
                    axi_out_busy <= not last_data_out;
                    axi_out_o.last <= last_data_out;
                    axi_out_o.valid <= '1';
                end if;
            elsif axi_out_o.valid then
                -- Exit the final state once accepted
                if axi_out_ready_i then
                    axi_out_o.valid <= '0';
                end if;
            elsif axi_out_start_i then
                -- Start a new cycle
                axi_out_address <= (others => '0');
                axi_out_busy <= '1';
            end if;

            -- Manage response
            if axi_out_response_ready_o and axi_out_response_i.valid then
                axi_out_ok_o <= axi_out_response_i.resp ?= "00";
                axi_out_response_ready_o <= '0';
            elsif axi_out_start_i then
                axi_out_response_ready_o <= '1';
            end if;
        end if;
    end process;

    axi_in_busy_o <= axi_in_ready_o;
    axi_in_count_o <= axi_in_address;
    axi_out_busy_o <= axi_out_busy or axi_out_o.valid;
    axi_out_count_o <= reg_write_address;
end;
