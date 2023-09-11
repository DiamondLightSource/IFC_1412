-- PHY interface for one byte (two nibbles, 13 bits)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.support.all;

entity gddr6_phy_byte is
    generic (
        -- Selects which bitslices to instantiate
        BITSLICE_WANTED : std_ulogic_vector(0 to 11);
        REFCLK_FREQUENCY : real;
        INITIAL_DELAY : natural;

        -- For the lower nibble, the clock either comes from bitslice 0 or from
        -- another byte, and clocks are distributed to adjacent bytes
        CLK_FROM_PIN : boolean;         -- Set if clock from bitslice 0
        CLK_TO_NORTH : boolean;         -- Set if clock to north enabled
        CLK_TO_SOUTH : boolean          -- Set if clock to south enabled
    );

    port (
        -- Clocks
        pll_clk_i : in std_ulogic;      -- Backbone clock from PLL
        fifo_rd_clk_i : in std_ulogic;  -- Clock for reading RX FIFO

        -- FIFO control
        fifo_empty_o : out std_ulogic;
        fifo_enable_i : in std_ulogic;

        -- Resets and controls
        reset_i : in std_ulogic;
        enable_control_vtc_i : in std_ulogic;
        enable_tri_vtc_i : in std_ulogic_vector(0 to 1);
        enable_bitslice_vtc_i : in std_ulogic_vector(0 to 11);
        dly_ready_o : out std_ulogic;
        vtc_ready_o : out std_ulogic;

        -- RIU interface
        riu_clk_i : in std_ulogic;      -- Control clock
        riu_addr_i : in unsigned(6 downto 0);
        riu_wr_data_i : in std_ulogic_vector(15 downto 0);
        riu_rd_data_o : out std_ulogic_vector(15 downto 0);
        riu_valid_o : out std_ulogic;
        riu_wr_en_i : in std_ulogic;

        -- Data interface
        data_o : out vector_array(0 to 11)(7 downto 0);
        data_i : in vector_array(0 to 11)(7 downto 0);
        output_enable_i : in std_ulogic_vector(3 downto 0);

        pad_in_i : in std_ulogic_vector(0 to 11);
        pad_out_o : out std_ulogic_vector(0 to 11);
        pad_t_out_o : out std_ulogic_vector(0 to 11);

        -- Inter-byte clocking
        clk_from_ext_i : in std_ulogic;
        clk_to_north_o : out std_ulogic;
        clk_to_south_o : out std_ulogic
    );
end;

architecture arch of gddr6_phy_byte is
    -- Inter-nibble and -byte clocking
    signal clk_to_north_out : std_ulogic_vector(0 to 1);
    signal clk_to_south_out : std_ulogic_vector(0 to 1);
    signal pclk_nibble_in : std_ulogic_vector(0 to 1);
    signal nclk_nibble_in : std_ulogic_vector(0 to 1);
    signal pclk_nibble_out : std_ulogic_vector(0 to 1);
    signal nclk_nibble_out : std_ulogic_vector(0 to 1);

    signal riu_rd_data : vector_array(0 to 1)(15 downto 0);
    signal riu_valid : std_ulogic_vector(0 to 1);
    signal riu_nibble_sel : std_ulogic_vector(0 to 1);

    signal fifo_empty : std_ulogic_vector(0 to 11);
    signal dly_ready : std_ulogic_vector(0 to 1);
    signal vtc_ready : std_ulogic_vector(0 to 1);

begin
    -- Generate the two nibbles.  The bottom nibble is connected to external
    -- clocking, and the two nibbles are interconnected
    gen_nibble : for i in 0 to 1 generate
        subtype BITSLICE_RANGE is natural range 6*i to 6*i + 5;
        constant LOWER_NIBBLE : boolean := i = 0;
        signal clk_from_ext : std_ulogic;

        signal output_enable : std_ulogic_vector(3 downto 0);

    begin
        if_clk : if i = 0 and not CLK_FROM_PIN generate
            -- Only route clk_from_ext_i to the lower nibble when the clock is
            -- not incoming from bitslice 0.
            clk_from_ext <= clk_from_ext_i;
        else generate
            clk_from_ext <= '1';
        end generate;

        nibble : entity work.gddr6_phy_nibble generic map (
            BITSLICE_WANTED => BITSLICE_WANTED(BITSLICE_RANGE),
            REFCLK_FREQUENCY => REFCLK_FREQUENCY,
            INITIAL_DELAY => INITIAL_DELAY,

            LOWER_NIBBLE => LOWER_NIBBLE,
            CLK_FROM_PIN => LOWER_NIBBLE and CLK_FROM_PIN,
            CLK_TO_NORTH => LOWER_NIBBLE and CLK_TO_NORTH,
            CLK_TO_SOUTH => LOWER_NIBBLE and CLK_TO_SOUTH
        ) port map (
            pll_clk_i => pll_clk_i,
            fifo_rd_clk_i => fifo_rd_clk_i,

            fifo_empty_o => fifo_empty(BITSLICE_RANGE),
            fifo_rd_en_i => fifo_enable_i,

            reset_i => reset_i,
            enable_control_vtc_i => enable_control_vtc_i,
            enable_tri_vtc_i => enable_tri_vtc_i(i),
            enable_bitslice_vtc_i => enable_bitslice_vtc_i(BITSLICE_RANGE),
            dly_ready_o => dly_ready(i),
            vtc_ready_o => vtc_ready(i),

            riu_clk_i => riu_clk_i,
            riu_addr_i => riu_addr_i(5 downto 0),
            riu_wr_data_i => riu_wr_data_i,
            riu_rd_data_o => riu_rd_data(i),
            riu_valid_o => riu_valid(i),
            riu_wr_en_i => riu_wr_en_i,
            riu_nibble_sel_i => riu_nibble_sel(i),

            data_o => data_o(BITSLICE_RANGE),
            data_i => data_i(BITSLICE_RANGE),
            output_enable_i => output_enable,

            pad_in_i => pad_in_i(BITSLICE_RANGE),
            pad_out_o => pad_out_o(BITSLICE_RANGE),
            pad_t_out_o => pad_t_out_o(BITSLICE_RANGE),

            clk_from_ext_i => clk_from_ext,
            clk_to_north_o => clk_to_north_out(i),
            clk_to_south_o => clk_to_south_out(i),
            pclk_nibble_i => pclk_nibble_in(i),
            nclk_nibble_i => nclk_nibble_in(i),
            pclk_nibble_o => pclk_nibble_out(i),
            nclk_nibble_o => nclk_nibble_out(i)
        );

        -- Align output enable with data stream
        process (fifo_rd_clk_i) begin
            if rising_edge(fifo_rd_clk_i) then
                output_enable <= output_enable_i;
            end if;
        end process;
    end generate;


    -- Use built-in for data multiplexing, wired as described in UG571 (v1.14)
    -- p325
    riu_or_i : RIU_OR port map (
        RIU_RD_DATA => riu_rd_data_o,
        RIU_RD_VALID => riu_valid_o,
        RIU_RD_DATA_LOW => riu_rd_data(0),
        RIU_RD_DATA_UPP => riu_rd_data(1),
        RIU_RD_VALID_LOW => riu_valid(0),
        RIU_RD_VALID_UPP => riu_valid(1)
    );
    riu_nibble_sel(0) <= riu_addr_i(6);
    riu_nibble_sel(1) <= not riu_addr_i(6);


    -- Inter-nibble plumbing
    pclk_nibble_in <= (0 => pclk_nibble_out(1), 1 => pclk_nibble_out(0));
    nclk_nibble_in <= (0 => nclk_nibble_out(1), 1 => nclk_nibble_out(0));

    -- Inter-byte clocks out from lower nibble
    clk_to_north_o <= clk_to_north_out(0);
    clk_to_south_o <= clk_to_south_out(0);

    -- Aggregate empty and ready statuses across both nibbles
    fifo_empty_o <= vector_or(fifo_empty);
    dly_ready_o <= vector_and(dly_ready);
    vtc_ready_o <= vector_and(vtc_ready);
end;
