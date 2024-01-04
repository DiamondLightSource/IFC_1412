-- Bitslice instantiation for a single IO bank

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_config_defs.all;
use work.gddr6_phy_defs.all;

entity gddr6_phy_dq is
    generic (
        REFCLK_FREQUENCY : real
    );
    port (
        -- Clocks
        phy_clk_i : in std_ulogic_vector(0 to 1);   -- Dedicated TX clock
        wck_i : in std_ulogic_vector(0 to 1);       -- RX data clocks
        ck_clk_i : in std_ulogic;                   -- General CK/data clock
        riu_clk_i : in std_ulogic;                  -- Delay control clock

        -- Resets and control
        bitslice_reset_i : in std_ulogic;           -- Bitslice reset
        enable_control_vtc_i : in std_ulogic;
        enable_bitslice_control_i : in std_ulogic;
        dly_ready_o : out std_ulogic;               -- Delay ready (async)
        vtc_ready_o : out std_ulogic;               -- Calibration done (async)
        reset_fifo_i : in std_ulogic_vector(0 to 1);
        fifo_ok_o : out std_ulogic_vector(0 to 1);
        capture_dbi_i : in std_ulogic;              -- Select edc_out_o source
        edc_delay_i : in unsigned(4 downto 0);      -- Alignment of EDC sources
        enable_dbi_i : in std_ulogic;               -- Data Bus Inversion

        -- Data interface, all values for a single CA tick, all on ck_clk_i
        data_o : out std_ulogic_vector(511 downto 0);
        data_i : in std_ulogic_vector(511 downto 0);
        output_enable_i : in std_ulogic;
        edc_in_o : out vector_array(7 downto 0)(7 downto 0);
        edc_out_o : out vector_array(7 downto 0)(7 downto 0);
        edc_i : in std_ulogic;      -- Config value only
        edc_t_i : in std_ulogic;    -- Output only enabled during config

        -- RX/TX DELAY controls
        delay_control_i : in delay_control_t;
        -- Delay readbacks
        delay_readbacks_o : out delay_readbacks_t;

        -- IO ports
        io_dq_o : out std_ulogic_vector(63 downto 0);
        io_dq_i : in std_ulogic_vector(63 downto 0);
        io_dq_t_o : out std_ulogic_vector(63 downto 0);
        io_dbi_n_o : out std_ulogic_vector(7 downto 0);
        io_dbi_n_i : in std_ulogic_vector(7 downto 0);
        io_dbi_n_t_o : out std_ulogic_vector(7 downto 0);
        io_edc_i : in std_ulogic_vector(7 downto 0);
        io_edc_o : out std_ulogic_vector(7 downto 0);
        io_edc_t_o : out std_ulogic_vector(7 downto 0);

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

    -- Status signals from individual bytes, no remapping required
    signal slice_fifo_empty : std_ulogic_vector(0 to 7);
    signal slice_dly_ready : std_ulogic_vector(0 to 7);
    signal slice_vtc_ready : std_ulogic_vector(0 to 7);

    -- Signals organised by slice ready for remapping
    --
    -- VTC enables
    signal slice_enable_tri_vtc : vector_array(0 to 7)(0 to 1);
    signal slice_enable_rx_vtc : vector_array(0 to 7)(0 to 11);
    signal slice_enable_tx_vtc : vector_array(0 to 7)(0 to 11);
    -- Delay control
    signal slice_tri_delay_ce : vector_array(0 to 7)(0 to 1);
    signal slice_rx_delay_ce : vector_array(0 to 7)(0 to 11);
    signal slice_tx_delay_ce : vector_array(0 to 7)(0 to 11);
    -- Delay readbacks
    signal slice_tri_delay : vector_array_array(0 to 7)(0 to 1)(8 downto 0);
    signal slice_rx_delay : vector_array_array(0 to 7)(0 to 11)(8 downto 0);
    signal slice_tx_delay : vector_array_array(0 to 7)(0 to 11)(8 downto 0);
    -- Data interface
    signal slice_data_out : vector_array_array(0 to 7)(0 to 11)(7 downto 0);
    signal slice_data_in : vector_array_array(0 to 7)(0 to 11)(7 downto 0);
    -- IO pads
    signal slice_pad_in : vector_array(0 to 7)(0 to 11);
    signal slice_pad_out : vector_array(0 to 7)(0 to 11);
    signal slice_pad_t_out : vector_array(0 to 7)(0 to 11);

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

    -- Separate FIFO enables for the two IO banks
    signal fifo_enable : std_ulogic_vector(0 to 1) := (others => '0');

begin
    -- Generate 4 IO bytes in each of the two IO banks
    gen_bytes : for i in 0 to 7 generate
        byte : entity work.gddr6_phy_byte generic map (
            BITSLICE_WANTED => bitslice_wanted(i),
            BITSLICE_EDC => bitslice_wanted(i, CONFIG_BANK_EDC),

            REFCLK_FREQUENCY => REFCLK_FREQUENCY,

            CLK_FROM_PIN => MAP_CLK_FROM_PIN(i mod 4),
            CLK_TO_NORTH => MAP_CLK_TO_NORTH(i mod 4),
            CLK_TO_SOUTH => MAP_CLK_TO_SOUTH(i mod 4)
        ) port map (
            phy_clk_i => phy_clk_i(i / 4),
            ck_clk_i => ck_clk_i,
            riu_clk_i => riu_clk_i,

            fifo_empty_o => slice_fifo_empty(i),
            fifo_enable_i => fifo_enable(i / 4),

            bitslice_reset_i => bitslice_reset_i,
            enable_control_vtc_i => enable_control_vtc_i,
            enable_bitslice_control_i => enable_bitslice_control_i,
            dly_ready_o => slice_dly_ready(i),
            vtc_ready_o => slice_vtc_ready(i),

            enable_tri_vtc_i => slice_enable_tri_vtc(i),
            enable_tx_vtc_i => slice_enable_tx_vtc(i),
            enable_rx_vtc_i => slice_enable_rx_vtc(i),

            delay_up_down_n_i => delay_control_i.up_down_n,
            tri_delay_ce_i => slice_tri_delay_ce(i),
            rx_delay_ce_i => slice_rx_delay_ce(i),
            tx_delay_ce_i => slice_tx_delay_ce(i),
            tri_delay_o => slice_tri_delay(i),
            tx_delay_o => slice_tx_delay(i),
            rx_delay_o => slice_rx_delay(i),

            data_i => slice_data_out(i),
            data_o => slice_data_in(i),
            output_enable_i => (others => output_enable_i),
            edc_t_i => edc_t_i,

            pad_in_i => slice_pad_in(i),
            pad_out_o => slice_pad_out(i),
            pad_t_out_o => slice_pad_t_out(i),

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
        slice_data_o => slice_data_out,
        slice_data_i => slice_data_in,
        slice_pad_in_o => slice_pad_in,
        slice_pad_out_i => slice_pad_out,
        slice_pad_t_out_i => slice_pad_t_out,
        -- VTC controls
        slice_enable_tri_vtc_o => slice_enable_tri_vtc,
        slice_enable_rx_vtc_o => slice_enable_rx_vtc,
        slice_enable_tx_vtc_o => slice_enable_tx_vtc,
        -- Delay control
        slice_rx_delay_ce_o => slice_rx_delay_ce,
        slice_tx_delay_ce_o => slice_tx_delay_ce,
        -- Delay readbacks
        slice_rx_delay_i => slice_rx_delay,
        slice_tx_delay_i => slice_tx_delay,

        -- Remapped data stream organised by tick
        bank_data_o => bank_data_in,
        bank_data_i => bank_data_out,
        bank_dbi_n_o => bank_dbi_n_in,
        bank_dbi_n_i => bank_dbi_n_out,
        bank_edc_o => bank_edc_in,
        bank_edc_i => edc_i,

        -- Delay control
        delay_control_i => delay_control_i,
        -- Delay readbacks
        delay_readbacks_o => delay_readbacks_o,

        -- Patch inputs for locating bitslice 0 where required
        bitslice_patch_i => bitslice_patch_i,

        -- IO pins
        io_dq_o => io_dq_o,
        io_dq_i => io_dq_i,
        io_dq_t_o => io_dq_t_o,
        io_dbi_n_o => io_dbi_n_o,
        io_dbi_n_i => io_dbi_n_i,
        io_dbi_n_t_o => io_dbi_n_t_o,
        io_edc_i => io_edc_i,
        io_edc_o => io_edc_o,
        io_edc_t_o => io_edc_t_o
    );


    -- Apply bitslip correction to raw data
    bitslip : entity work.gddr6_phy_bitslip port map (
        clk_i => ck_clk_i,

        delay_i => delay_control_i.bitslip_delay,
        delay_strobe_i => delay_control_i.bitslip_strobe,

        slice_dq_i => bank_data_in,
        slice_dbi_n_i => bank_dbi_n_in,
        slice_edc_i => bank_edc_in,

        fixed_dq_o => bitslip_data_in,
        fixed_dbi_n_o => bitslip_dbi_n_in,
        fixed_edc_o => bitslip_edc_in
    );

    -- We shouldn't need bitslip for outgoing data
    bank_data_out <= bitslip_data_out;
    bank_dbi_n_out <= bitslip_dbi_n_out;


    -- Finally flatten the data across 8 ticks.  At this point we also apply
    -- DBI if appropriate
    dbi : entity work.gddr6_phy_map_dbi port map (
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

        capture_dbi_i => capture_dbi_i,
        edc_delay_i => edc_delay_i,

        output_enable_i => output_enable_i,
        data_in_i => bitslip_data_in,
        dbi_n_in_i => bitslip_dbi_n_in,
        data_out_i => bitslip_data_out,
        dbi_n_out_i => bitslip_dbi_n_out,

        edc_out_o => edc_out_o,

        edc_in_i => bitslip_edc_in,
        edc_in_o => edc_in_o
    );


    -- FIFO management and reset
    process (ck_clk_i) begin
        if rising_edge(ck_clk_i) then
            for io in 0 to 1 loop
                if bitslice_reset_i or reset_fifo_i(io) then
                    fifo_enable(io) <= '0';
                else
                    -- Enable FIFO following UG571 v1.14 p213
                    -- We do this separately for each IO bank to account for the
                    -- separate clocking for each bank
                    fifo_enable(io) <=
                        not (or slice_fifo_empty(4*io to 4*io + 3));
                end if;
                fifo_ok_o(io) <= fifo_enable(io);
            end loop;
        end if;
    end process;

    -- TRI output delays are not controlled at present
    slice_tri_delay_ce <= (others => (others => '0'));

    -- Gather statuses needed for resets
    dly_ready_o <= and slice_dly_ready;
    vtc_ready_o <= and slice_vtc_ready;
end;
