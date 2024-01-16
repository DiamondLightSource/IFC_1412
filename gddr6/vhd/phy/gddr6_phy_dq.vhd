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
        clk_i : in std_ulogic;

        -- Controls
        edc_delay_i : in unsigned(4 downto 0);      -- Alignment of EDC sources
        enable_dbi_i : in std_ulogic;               -- Data Bus Inversion
        train_dbi_i : in std_ulogic;                -- Enable DBI training
        -- RX/TX DELAY controls
        delay_control_i : in bitslip_delay_control_t;
        delay_readbacks_o : out bitslip_delay_readbacks_t;

        -- Unaligned raw data from bitslices
        raw_data_o : out vector_array(63 downto 0)(7 downto 0);
        raw_data_i : in vector_array(63 downto 0)(7 downto 0);
        raw_dbi_n_o : out vector_array(7 downto 0)(7 downto 0);
        raw_dbi_n_i : in vector_array(7 downto 0)(7 downto 0);
        raw_edc_i : in vector_array(7 downto 0)(7 downto 0);

        -- Data interface, all values for a single CA tick
        output_enable_i : in std_ulogic;
        data_o : out std_ulogic_vector(511 downto 0);
        data_i : in std_ulogic_vector(511 downto 0);
        dbi_n_i : in vector_array(7 downto 0)(7 downto 0);
        dbi_n_o : out vector_array(7 downto 0)(7 downto 0);
        edc_in_o : out vector_array(7 downto 0)(7 downto 0);
        edc_out_o : out vector_array(7 downto 0)(7 downto 0)
    );
end;

architecture arch of gddr6_phy_dq is
    -- Data after bitslip correction
    signal bitslip_data_out : vector_array(63 downto 0)(7 downto 0);
    signal bitslip_data_in : vector_array(63 downto 0)(7 downto 0);
    signal bitslip_dbi_n_out : vector_array(7 downto 0)(7 downto 0);
    signal bitslip_dbi_n_in : vector_array(7 downto 0)(7 downto 0);
    signal bitslip_edc_in : vector_array(7 downto 0)(7 downto 0);

    -- Delay readbacks
    signal dq_tx_delay : unsigned_array(63 downto 0)(2 downto 0);
    signal dbi_tx_delay : unsigned_array(7 downto 0)(2 downto 0);

begin
    -- Apply bitslip correction to raw data
    bitslip_out : entity work.gddr6_phy_bitslip port map (
        clk_i => clk_i,

        delay_i => delay_control_i.delay,
        delay_o(DELAY_DQ_RANGE) => dq_tx_delay,
        delay_o(DELAY_DBI_RANGE) => dbi_tx_delay,
        strobe_i(DELAY_DQ_RANGE) => delay_control_i.dq_tx_strobe,
        strobe_i(DELAY_DBI_RANGE) => delay_control_i.dbi_tx_strobe,

        data_i(DELAY_DQ_RANGE) => bitslip_data_out,
        data_i(DELAY_DBI_RANGE) => bitslip_dbi_n_out,
        data_o(DELAY_DQ_RANGE) => raw_data_o,
        data_o(DELAY_DBI_RANGE) => raw_dbi_n_o
    );

    -- Looks like we need bitslip on TX but not RX data.  A bit surprising...
    bitslip_data_in <= raw_data_i;
    bitslip_dbi_n_in <= raw_dbi_n_i;
    bitslip_edc_in <= raw_edc_i;

    delay_readbacks_o <= (
        dq_tx_delay => dq_tx_delay,
        dbi_tx_delay => dbi_tx_delay
    );


    -- Finally flatten the data across 8 ticks.  At this point we also apply
    -- DBI if appropriate
    dbi : entity work.gddr6_phy_dbi port map (
        clk_i => clk_i,

        enable_dbi_i => enable_dbi_i,
        bank_data_i => bitslip_data_in,
        bank_data_o => bitslip_data_out,
        bank_dbi_n_i => bitslip_dbi_n_in,
        bank_dbi_n_o => bitslip_dbi_n_out,

        enable_training_i => train_dbi_i,
        train_dbi_n_i => dbi_n_i,
        train_dbi_n_o => dbi_n_o,

        data_i => data_i,
        data_o => data_o
    );


    -- Compute CRC on data passing over the wire
    crc : entity work.gddr6_phy_crc port map (
        clk_i => clk_i,

        edc_delay_i => edc_delay_i,

        output_enable_i => output_enable_i,
        data_in_i => bitslip_data_in,
        dbi_n_in_i => bitslip_dbi_n_in,
        data_out_i => bitslip_data_out,
        dbi_n_out_i => bitslip_dbi_n_out,

        edc_out_o => edc_out_o
    );
    edc_in_o <= bitslip_edc_in;
end;
