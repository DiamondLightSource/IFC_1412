-- Bitslice instantiation for a single IO bank

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_config_defs.all;

entity gddr6_phy_dq is
    generic (
        REFCLK_FREQUENCY : real
    );
    port (
        -- Clocks
        pll_clk_i : in std_ulogic_vector(0 to 1);   -- Dedicated TX clock
        clk_i : in std_ulogic;                      -- General register clock
        wck_i : in std_ulogic_vector(0 to 1);       -- RX data clocks

        -- Resets and control
        reset_i : in std_ulogic;                -- Bitslice reset
        dly_ready_o : out std_ulogic;           -- Delay ready (async)
        vtc_ready_o : out std_ulogic;           -- Calibration done (async)
        enable_control_vtc_i : in std_ulogic;
        fifo_ok_o : out std_ulogic;

        -- Data interface, all values for a single CA tick
        data_o : out std_ulogic_vector(511 downto 0);
        data_i : in std_ulogic_vector(511 downto 0);
        dq_t_i : in std_ulogic;
        enable_dbi_i : in std_ulogic;
        edc_in_o : out vector_array(7 downto 0)(7 downto 0);
        edc_out_o : out vector_array(7 downto 0)(7 downto 0);

        -- Delay Control
        -- The entries are multiplexed into 64+8+8+16 = 96 bits with the
        -- following assignments:
        --      15:0    DQ 1A   )
        --      31:16   DQ 1B   ) 64 bits
        --      47:32   DQ 2A   )
        --      63:48   DQ 2B   )
        --      71:64   DBI     8 bits, one per byte
        --      79:72   EDC     8 bits, one per byte
        --      95:80   TRI     16, one per nibble
        delay_i : in std_ulogic_vector(8 downto 0);
        delay_rx_tx_n_i : in std_ulogic;                    -- RX or TX*
        enable_vtc_i : in std_ulogic_vector(0 to 95);
        load_delay_i : in std_ulogic_vector(0 to 95);
        delay_o : out vector_array(0 to 95)(8 downto 0);

        -- IO ports
        io_dq_o : out std_ulogic_vector(63 downto 0);
        io_dq_i : in std_ulogic_vector(63 downto 0);
        io_dq_t_o : out std_ulogic_vector(63 downto 0);
        io_dbi_n_o : out std_ulogic_vector(7 downto 0);
        io_dbi_n_i : in std_ulogic_vector(7 downto 0);
        io_dbi_n_t_o : out std_ulogic_vector(7 downto 0);
        io_edc_i : in std_ulogic_vector(7 downto 0)
    );
end;

architecture arch of gddr6_phy_dq is
    -- Clock distribution definitions.  The RX clock arrives on bit 0 of byte 1
    -- and is distributed vertically 1 => 2 => 3 (CLK_TO_NORTH) and 1 => 0
    -- (CLK_TO_SOUTH).  These constants guide the plumbing of individual bytes.
    constant MAP_CLK_FROM_PIN : boolean_array := (false, true, false, false);
    constant MAP_CLK_TO_NORTH : boolean_array := (false, true, true,  false);
    constant MAP_CLK_TO_SOUTH : boolean_array := (false, true, false, false);

    -- RX clocking distribution network
    signal clk_from_ext : std_ulogic_vector(0 to 7);
    signal clk_to_north : std_ulogic_vector(0 to 7);
    signal clk_to_south : std_ulogic_vector(0 to 7);

    -- Status signals from individual bytes
    signal fifo_empty : std_ulogic_vector(0 to 7);
    signal dly_ready : std_ulogic_vector(0 to 7);
    signal vtc_ready : std_ulogic_vector(0 to 7);
    signal fifo_enable : std_ulogic := '0';

    -- Arrays of bitslice resources ready for mapping
    signal enable_bitslice_vtc : vector_array(0 to 7)(0 to 11);
    signal rx_load_in : vector_array(0 to 7)(0 to 11);
    signal rx_delay_out : vector_array_array(0 to 7)(0 to 11)(8 downto 0);
    signal tx_load_in : vector_array(0 to 7)(0 to 11);
    signal tx_delay_out : vector_array_array(0 to 7)(0 to 11)(8 downto 0);
    signal data_out : vector_array_array(0 to 7)(0 to 11)(7 downto 0);
    signal data_in : vector_array_array(0 to 7)(0 to 11)(7 downto 0);
    signal pad_in_in : vector_array(0 to 7)(0 to 11);
    signal pad_out_out : vector_array(0 to 7)(0 to 11);
    signal pad_t_out_out : vector_array(0 to 7)(0 to 11);

    -- Map for tri delays (2 per byte)
    signal delay_tri_out : vector_array(0 to 15)(8 downto 0);
    signal delay_tri_vtc_in : std_ulogic_vector(0 to 15);
    signal delay_tri_load_in : std_ulogic_vector(0 to 15);

    -- Raw data organised by pin and tick
    signal bank_data_out : vector_array(63 downto 0)(7 downto 0);
    signal bank_data_in : vector_array(63 downto 0)(7 downto 0);
    signal bank_dbi_n_out : vector_array(7 downto 0)(7 downto 0);
    signal bank_dbi_n_in : vector_array(7 downto 0)(7 downto 0);
    signal bank_edc_in : vector_array(7 downto 0)(7 downto 0);
    -- Registered dq_t_i to track registered bank_data_out
    signal dq_t_in : std_ulogic := '1';

    -- Decode ranges for delay control groups
    subtype DELAY_DQ_RANGE is natural range 0 to 63;
    subtype DELAY_DBI_RANGE is natural range 64 to 71;
    subtype DELAY_EDC_RANGE is natural range 72 to 79;
    subtype DELAY_TRI_RANGE is natural range 80 to 95;

begin
    -- Generate 4 IO bytes in each of the two IO banks
    gen_bytes : for i in 0 to 7 generate
        -- Selector for nibble specific outputs
        subtype NIBBLE_SUBRANGE is natural range 2*i to 2*i+1;
    begin
        byte : entity work.gddr6_phy_byte generic map (
            REFCLK_FREQUENCY => REFCLK_FREQUENCY,
            BITSLICE_WANTED => bitslice_wanted(i),
            CLK_FROM_PIN => MAP_CLK_FROM_PIN(i mod 4),
            CLK_TO_NORTH => MAP_CLK_TO_NORTH(i mod 4),
            CLK_TO_SOUTH => MAP_CLK_TO_SOUTH(i mod 4)
        ) port map (
            pll_clk_i => pll_clk_i(i / 4),
            fifo_rd_clk_i => clk_i,
            reg_clk_i => clk_i,

            fifo_empty_o => fifo_empty(i),
            fifo_enable_i => fifo_enable,

            reset_i => reset_i,
            enable_control_vtc_i => enable_control_vtc_i,
            enable_tri_vtc_i => delay_tri_vtc_in(NIBBLE_SUBRANGE),
            enable_bitslice_vtc_i => enable_bitslice_vtc(i),
            dly_ready_o => dly_ready(i),
            vtc_ready_o => vtc_ready(i),

            rx_load_i => rx_load_in(i),
            rx_delay_i => delay_i,
            rx_delay_o => rx_delay_out(i),
            tx_load_i => tx_load_in(i),
            tx_delay_i => delay_i,
            tx_delay_o => tx_delay_out(i),
            tri_load_i =>
                delay_tri_load_in(NIBBLE_SUBRANGE) and not delay_rx_tx_n_i,
            tri_delay_i => delay_i,
            tri_delay_o => delay_tri_out(NIBBLE_SUBRANGE),

            data_o => data_out(i),
            data_i => data_in(i),
            tbyte_i => (others => dq_t_in),

            pad_in_i => pad_in_in(i),
            pad_out_o => pad_out_out(i),
            pad_t_out_o => pad_t_out_out(i),

            clk_from_ext_i => clk_from_ext(i),
            clk_to_north_o => clk_to_north(i),
            clk_to_south_o => clk_to_south(i)
        );
    end generate;

    -- Clock plumbing mirroring clock distribution in constants
    clk_from_ext <= (
        -- IO bank 1
        0 => clk_to_south(1),
        1 => '1',
        2 => clk_to_north(1),
        3 => clk_to_north(2),
        -- IO bank 2
        4 => clk_to_south(5),
        5 => '1',
        6 => clk_to_north(5),
        7 => clk_to_north(6)
    );


    -- Map between byte and slices and all the various signals of interest
    map_slices : entity work.gddr6_phy_dq_remap port map (
        -- Clocks
        wck_i => wck_i,

        -- Bitslice mapped resources
        enable_bitslice_vtc_o => enable_bitslice_vtc,
        rx_load_o => rx_load_in,
        rx_delay_i => rx_delay_out,
        tx_load_o => tx_load_in,
        tx_delay_i => tx_delay_out,
        data_i => data_out,
        data_o => data_in,
        pad_in_o => pad_in_in,
        pad_out_i => pad_out_out,
        pad_t_out_i => pad_t_out_out,

        -- Remapped data stream organised by tick
        bank_data_o => bank_data_in,
        bank_data_i => bank_data_out,
        bank_dbi_n_o => bank_dbi_n_in,
        bank_dbi_n_i => bank_dbi_n_out,
        bank_edc_o => bank_edc_in,

        -- Map delay controls to appropriate address ranges
        delay_rx_tx_n_i => delay_rx_tx_n_i,
        delay_dq_o => delay_o(DELAY_DQ_RANGE),
        delay_dq_vtc_i => enable_vtc_i(DELAY_DQ_RANGE),
        delay_dq_load_i => load_delay_i(DELAY_DQ_RANGE),
        delay_dbi_o => delay_o(DELAY_DBI_RANGE),
        delay_dbi_vtc_i => enable_vtc_i(DELAY_DBI_RANGE),
        delay_dbi_load_i => load_delay_i(DELAY_DBI_RANGE),
        delay_edc_o => delay_o(DELAY_EDC_RANGE),
        delay_edc_vtc_i => enable_vtc_i(DELAY_EDC_RANGE),
        delay_edc_load_i => load_delay_i(DELAY_EDC_RANGE),

        -- IO pins
        io_dq_o => io_dq_o,
        io_dq_i => io_dq_i,
        io_dq_t_o => io_dq_t_o,
        io_dbi_n_o => io_dbi_n_o,
        io_dbi_n_i => io_dbi_n_i,
        io_dbi_n_t_o => io_dbi_n_t_o,
        io_edc_i => io_edc_i
    );

    -- Map tri delay controls onto inputs and outputs
    delay_tri_vtc_in <= enable_vtc_i(DELAY_TRI_RANGE);
    delay_tri_load_in <= load_delay_i(DELAY_TRI_RANGE);
    delay_o(DELAY_TRI_RANGE) <= delay_tri_out;


    -- Finally flatten the data across 8 ticks.  At this point we also apply
    -- DBI if appropriate
    map_data : entity work.gddr6_phy_map_data port map (
        clk_i => clk_i,

        enable_dbi_i => enable_dbi_i,

        bank_data_i => bank_data_in,
        bank_data_o => bank_data_out,
        bank_dbi_n_i => bank_dbi_n_in,
        bank_dbi_n_o => bank_dbi_n_out,

        data_i => data_i,
        data_o => data_o
    );


    -- Compute CRC on data passing over the wire
    crc : entity work.gddr6_phy_crc port map (
        clk_i => clk_i,

        dq_t_i => dq_t_in,
        bank_data_in_i => bank_data_in,
        bank_dbi_n_in_i => bank_dbi_n_in,
        bank_data_out_i => bank_data_out,
        bank_dbi_n_out_i => bank_dbi_n_out,

        edc_out_o => edc_out_o
    );
    edc_in_o <= bank_edc_in;


    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Enable FIFO following UG571 v1.14 p213
            fifo_enable <= not vector_or(fifo_empty);
            fifo_ok_o <= fifo_enable;
            -- Align dq_t with data out
            dq_t_in <= dq_t_i;
        end if;
    end process;


    -- Gather statuses needed for resets
    dly_ready_o <= vector_and(dly_ready);
    vtc_ready_o <= vector_and(vtc_ready);
end;
