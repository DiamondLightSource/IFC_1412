-- Encapsulates instantiation of all bitslices and mapping of signals

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_config_defs.all;
use work.gddr6_phy_defs.all;

entity gddr6_phy_bitslices is
    generic (
        REFCLK_FREQUENCY : real
    );
    port (
        -- Clocks
        phy_clk_i : in std_ulogic_vector(0 to 1);   -- Dedicated TX clock
        wck_i : in std_ulogic_vector(0 to 1);       -- RX data clocks
        ck_clk_i : in std_ulogic;                   -- General CK/data clock
        riu_clk_i : in std_ulogic;                  -- RIU clock for startup

        -- Resets and control
        bitslice_reset_i : in std_ulogic;           -- Bitslice reset
        enable_control_vtc_i : in std_ulogic;
        enable_bitslice_vtc_i : in std_ulogic;
        enable_bitslice_control_i : in std_ulogic;
        dly_ready_o : out std_ulogic;               -- Delay ready (async)
        vtc_ready_o : out std_ulogic;               -- Calibration done (async)
        fifo_ok_o : out std_ulogic_vector(0 to 1);

        -- Data interface, all values for a single CA tick, all on ck_clk_i
        output_enable_i : in std_ulogic;
        data_i : in phy_data_t;
        data_o : out phy_data_t;
        dbi_n_i : in phy_dbi_t;
        dbi_n_o : out phy_dbi_t;
        edc_o : out phy_edc_t;
        edc_i : in std_ulogic;      -- Config value only
        edc_t_i : in std_ulogic;    -- Output only enabled during config

        -- RX/TX DELAY controls
        delay_control_i : in bitslice_delay_control_t;
        -- Delay readbacks
        delay_readbacks_o : out bitslice_delay_readbacks_t;

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

architecture arch of gddr6_phy_bitslices is
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
    -- Delay control
    signal slice_rx_delay_ce : vector_array(0 to 7)(0 to 11);
    signal slice_tx_delay_ce : vector_array(0 to 7)(0 to 11);
    -- Delay readbacks
    signal slice_rx_delay : vector_array_array(0 to 7)(0 to 11)(8 downto 0);
    signal slice_tx_delay : vector_array_array(0 to 7)(0 to 11)(8 downto 0);
    -- Data interface
    signal slice_data_out : vector_array_array(0 to 7)(0 to 11)(7 downto 0);
    signal slice_data_in : vector_array_array(0 to 7)(0 to 11)(7 downto 0);
    -- IO pads
    signal slice_pad_in : vector_array(0 to 7)(0 to 11);
    signal slice_pad_out : vector_array(0 to 7)(0 to 11);
    signal slice_pad_t_out : vector_array(0 to 7)(0 to 11);

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
            enable_bitslice_vtc_i => enable_bitslice_vtc_i,
            enable_bitslice_control_i => enable_bitslice_control_i,
            dly_ready_o => slice_dly_ready(i),
            vtc_ready_o => slice_vtc_ready(i),

            delay_up_down_n_i => delay_control_i.up_down_n,
            rx_delay_ce_i => slice_rx_delay_ce(i),
            tx_delay_ce_i => slice_tx_delay_ce(i),
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
    map_slices : entity work.gddr6_phy_remap port map (
        -- Clocks
        wck_i => wck_i,

        -- Bitslice mapped resources
        slice_data_o => slice_data_out,
        slice_data_i => slice_data_in,
        slice_pad_in_o => slice_pad_in,
        slice_pad_out_i => slice_pad_out,
        slice_pad_t_out_i => slice_pad_t_out,
        -- Delay control
        slice_rx_delay_ce_o => slice_rx_delay_ce,
        slice_tx_delay_ce_o => slice_tx_delay_ce,
        -- Delay readbacks
        slice_rx_delay_i => slice_rx_delay,
        slice_tx_delay_i => slice_tx_delay,

        -- Remapped data stream organised by tick
        bank_data_o => data_o,
        bank_data_i => data_i,
        bank_dbi_n_o => dbi_n_o,
        bank_dbi_n_i => dbi_n_i,
        bank_edc_o => edc_o,
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


    -- FIFO management and reset
    process (ck_clk_i) begin
        if rising_edge(ck_clk_i) then
            for io in 0 to 1 loop
                if bitslice_reset_i then
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

    -- Gather statuses needed for resets
    dly_ready_o <= and slice_dly_ready;
    vtc_ready_o <= and slice_vtc_ready;
end;
