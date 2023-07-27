-- Bitslice instantiation for a single IO bank

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_config_defs.all;

entity gddr6_phy_dq is
    generic (
        REFCLK_FREQUENCY : real;
        INITIAL_DELAY : natural
    );
    port (
        -- Clocks
        pll_clk_i : in std_ulogic_vector(0 to 1);   -- Dedicated TX clock
        wck_i : in std_ulogic_vector(0 to 1);       -- RX data clocks
        ck_clk_i : in std_ulogic;                   -- General CK/data clock

        -- Resets and control
        reset_i : in std_ulogic;                -- Bitslice reset
        dly_ready_o : out std_ulogic;           -- Delay ready (async)
        vtc_ready_o : out std_ulogic;           -- Calibration done (async)
        enable_control_vtc_i : in std_ulogic;
        enable_bitslice_vtc_i : in std_ulogic;
        fifo_ok_o : out std_ulogic;

        -- Data interface, all values for a single CA tick, all on ck_clk_i
        data_o : out std_ulogic_vector(511 downto 0);
        data_i : in std_ulogic_vector(511 downto 0);
        dq_t_i : in std_ulogic;
        enable_dbi_i : in std_ulogic;
        edc_in_o : out vector_array(7 downto 0)(7 downto 0);
        edc_out_o : out vector_array(7 downto 0)(7 downto 0);

        -- RIU interface
        riu_clk_i : in std_ulogic;      -- Control clock
        riu_addr_i : in unsigned(9 downto 0);
        riu_wr_data_i : in std_ulogic_vector(15 downto 0);
        riu_rd_data_o : out std_ulogic_vector(15 downto 0);
        riu_valid_o : out std_ulogic;
        riu_wr_en_i : in std_ulogic;
        -- Bit phase control, 0 to 7 for top and bottom banks separately
        rx_slip_i : in unsigned_array(0 to 1)(2 downto 0);
        tx_slip_i : in unsigned_array(0 to 1)(2 downto 0);

        -- IO ports
        io_dq_o : out std_ulogic_vector(63 downto 0);
        io_dq_i : in std_ulogic_vector(63 downto 0);
        io_dq_t_o : out std_ulogic_vector(63 downto 0);
        io_dbi_n_o : out std_ulogic_vector(7 downto 0);
        io_dbi_n_i : in std_ulogic_vector(7 downto 0);
        io_dbi_n_t_o : out std_ulogic_vector(7 downto 0);
        io_edc_i : in std_ulogic_vector(7 downto 0);
        -- Fixup required to locate patchup bitslice
        bitslice_patch_i : in std_ulogic_vector
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
    signal enable_tri_vtc : vector_array(0 to 7)(0 to 1);
    signal enable_bitslice_vtc : vector_array(0 to 7)(0 to 11);
    signal data_out : vector_array_array(0 to 7)(0 to 11)(7 downto 0);
    signal data_in : vector_array_array(0 to 7)(0 to 11)(7 downto 0);
    signal pad_in_in : vector_array(0 to 7)(0 to 11);
    signal pad_out_out : vector_array(0 to 7)(0 to 11);
    signal pad_t_out_out : vector_array(0 to 7)(0 to 11);

    -- Raw data organised by pin and tick
    signal bank_data_out : vector_array(63 downto 0)(7 downto 0);
    signal bank_data_in : vector_array(63 downto 0)(7 downto 0);
    signal bank_dbi_n_out : vector_array(7 downto 0)(7 downto 0);
    signal bank_dbi_n_in : vector_array(7 downto 0)(7 downto 0);
    signal bank_edc_in : vector_array(7 downto 0)(7 downto 0);

    -- Raw data after bitslip correction
    signal bitslip_data_out : vector_array(63 downto 0)(7 downto 0);
    signal bitslip_data_in : vector_array(63 downto 0)(7 downto 0);
    signal bitslip_dbi_n_out : vector_array(7 downto 0)(7 downto 0);
    signal bitslip_dbi_n_in : vector_array(7 downto 0)(7 downto 0);
    signal bitslip_edc_in : vector_array(7 downto 0)(7 downto 0);

    -- RIU interface
    signal riu_byte : natural range 0 to 7;
    signal riu_rd_data : vector_array(0 to 7)(15 downto 0);
    signal riu_valid : std_ulogic_vector(0 to 7);
    signal riu_wr_en : std_ulogic_vector(0 to 7);

begin
    -- Generate 4 IO bytes in each of the two IO banks
    gen_bytes : for i in 0 to 7 generate
        byte : entity work.gddr6_phy_byte generic map (
            REFCLK_FREQUENCY => REFCLK_FREQUENCY,
            INITIAL_DELAY => INITIAL_DELAY,
            BITSLICE_WANTED => bitslice_wanted(i),
            CLK_FROM_PIN => MAP_CLK_FROM_PIN(i mod 4),
            CLK_TO_NORTH => MAP_CLK_TO_NORTH(i mod 4),
            CLK_TO_SOUTH => MAP_CLK_TO_SOUTH(i mod 4)
        ) port map (
            pll_clk_i => pll_clk_i(i / 4),
            fifo_rd_clk_i => ck_clk_i,

            fifo_empty_o => fifo_empty(i),
            fifo_enable_i => fifo_enable,

            reset_i => reset_i,
            enable_control_vtc_i => enable_control_vtc_i,
            enable_tri_vtc_i => enable_tri_vtc(i),
            enable_bitslice_vtc_i => enable_bitslice_vtc(i),
            dly_ready_o => dly_ready(i),
            vtc_ready_o => vtc_ready(i),

            riu_clk_i => riu_clk_i,
            riu_addr_i => riu_addr_i(6 downto 0),
            riu_wr_data_i => riu_wr_data_i,
            riu_rd_data_o => riu_rd_data(i),
            riu_valid_o => riu_valid(i),
            riu_wr_en_i => riu_wr_en(i),

            data_o => data_out(i),
            data_i => data_in(i),
            tbyte_i => (others => dq_t_i),

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

        -- Patch inputs for locating bitslice 0 where required
        bitslice_patch_i => bitslice_patch_i,

        -- IO pins
        io_dq_o => io_dq_o,
        io_dq_i => io_dq_i,
        io_dq_t_o => io_dq_t_o,
        io_dbi_n_o => io_dbi_n_o,
        io_dbi_n_i => io_dbi_n_i,
        io_dbi_n_t_o => io_dbi_n_t_o,
        io_edc_i => io_edc_i
    );


    -- Apply bitslip correction to raw data
    bitslip : entity work.gddr6_phy_bitslip port map (
        clk_i => ck_clk_i,

        rx_slip_i => rx_slip_i,
        tx_slip_i => tx_slip_i,

        slice_dq_i => bank_data_in,
        slice_dq_o => bank_data_out,
        slice_dbi_n_i => bank_dbi_n_in,
        slice_dbi_n_o => bank_dbi_n_out,
        slice_edc_i => bank_edc_in,

        fixed_dq_o => bitslip_data_in,
        fixed_dq_i => bitslip_data_out,
        fixed_dbi_n_o => bitslip_dbi_n_in,
        fixed_dbi_n_i => bitslip_dbi_n_out,
        fixed_edc_o => bitslip_edc_in
    );


    -- Finally flatten the data across 8 ticks.  At this point we also apply
    -- DBI if appropriate
    map_data : entity work.gddr6_phy_map_data port map (
        clk_i => ck_clk_i,

        enable_dbi_i => enable_dbi_i,

        bank_data_i => bitslip_data_in,
        bank_data_o => bitslip_data_out,
        bank_dbi_n_i => bitslip_dbi_n_in,
        bank_dbi_n_o => bitslip_dbi_n_out,

        data_i => data_i,
        data_o => data_o
    );

    -- Compute CRC on data passing over the wire
    crc : entity work.gddr6_phy_crc port map (
        clk_i => ck_clk_i,

        dq_t_i => dq_t_i,
        bank_data_in_i => bitslip_data_in,
        bank_dbi_n_in_i => bitslip_dbi_n_in,
        bank_data_out_i => bitslip_data_out,
        bank_dbi_n_out_i => bitslip_dbi_n_out,

        edc_out_o => edc_out_o
    );
    edc_in_o <= bitslip_edc_in;


    process (ck_clk_i) begin
        if rising_edge(ck_clk_i) then
            -- Enable FIFO following UG571 v1.14 p213
            fifo_enable <= not vector_or(fifo_empty);
            fifo_ok_o <= fifo_enable;
        end if;
    end process;

    -- Use top part of RIU address to select byte to act on
    riu_byte <= to_integer(riu_addr_i(9 downto 7));
    riu_rd_data_o <= riu_rd_data(riu_byte);
    riu_valid_o <= riu_valid(riu_byte);
    compute_strobe(riu_wr_en, riu_byte, riu_wr_en_i);

    -- For the moment we'll control all bitslice VTC signals together
    enable_tri_vtc <= (others => (others => enable_bitslice_vtc_i));
    enable_bitslice_vtc <= (others => (others => enable_bitslice_vtc_i));

    -- Gather statuses needed for resets
    dly_ready_o <= vector_and(dly_ready);
    vtc_ready_o <= vector_and(vtc_ready);
end;
