-- Signal alignment and processing for DQ/DBI/EDC

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
        data_o : out vector_array(63 downto 0)(7 downto 0);
        data_i : in vector_array(63 downto 0)(7 downto 0);
        dbi_n_i : in vector_array(7 downto 0)(7 downto 0);
        dbi_n_o : out vector_array(7 downto 0)(7 downto 0);

        -- EDC outputs
        edc_in_o : out vector_array(7 downto 0)(7 downto 0);
        edc_write_o : out vector_array(7 downto 0)(7 downto 0);
        edc_read_o : out vector_array(7 downto 0)(7 downto 0)
    );
end;

architecture arch of gddr6_phy_dq is
    -- For the moment we'll bypass RX bitslip
    constant ENABLE_RX_BITSLIP : boolean := false;

    -- Data between bitslip correction and DBI
    signal data_out : vector_array(63 downto 0)(7 downto 0);
    signal data_in : vector_array(63 downto 0)(7 downto 0);
    signal dbi_n_out : vector_array(7 downto 0)(7 downto 0);
    signal dbi_n_in : vector_array(7 downto 0)(7 downto 0);
    signal edc_in : vector_array(7 downto 0)(7 downto 0);

begin
    gen_in : if ENABLE_RX_BITSLIP generate
        bitslip_in : entity work.gddr6_phy_bitslip port map (
            clk_i => clk_i,

            delay_i => delay_control_i.delay,
            delay_o(DELAY_DQ_RANGE) => delay_readbacks_o.dq_rx_delay,
            delay_o(DELAY_DBI_RANGE) => delay_readbacks_o.dbi_rx_delay,
            delay_o(DELAY_EDC_RANGE) => delay_readbacks_o.edc_rx_delay,
            strobe_i(DELAY_DQ_RANGE) => delay_control_i.dq_rx_strobe,
            strobe_i(DELAY_DBI_RANGE) => delay_control_i.dbi_rx_strobe,
            strobe_i(DELAY_EDC_RANGE) => delay_control_i.edc_rx_strobe,

            data_i(DELAY_DQ_RANGE) => raw_data_i,
            data_i(DELAY_DBI_RANGE) => raw_dbi_n_i,
            data_i(DELAY_EDC_RANGE) => raw_edc_i,
            data_o(DELAY_DQ_RANGE) => data_in,
            data_o(DELAY_DBI_RANGE) => dbi_n_in,
            data_o(DELAY_EDC_RANGE) => edc_in
        );
    else generate
        -- Looks like we need bitslip on TX but not RX data.  Surprising...
        data_in <= raw_data_i;
        dbi_n_in <= raw_dbi_n_i;
        edc_in <= raw_edc_i;
        delay_readbacks_o.dq_rx_delay <= (others => "000");
        delay_readbacks_o.dbi_rx_delay <= (others => "000");
        delay_readbacks_o.edc_rx_delay <= (others => "000");
    end generate;

    -- Apply bitslip correction to raw data
    bitslip_out : entity work.gddr6_phy_bitslip port map (
        clk_i => clk_i,

        delay_i => delay_control_i.delay,
        delay_o(DELAY_DQ_RANGE) => delay_readbacks_o.dq_tx_delay,
        delay_o(DELAY_DBI_RANGE) => delay_readbacks_o.dbi_tx_delay,
        strobe_i(DELAY_DQ_RANGE) => delay_control_i.dq_tx_strobe,
        strobe_i(DELAY_DBI_RANGE) => delay_control_i.dbi_tx_strobe,

        data_i(DELAY_DQ_RANGE) => data_out,
        data_i(DELAY_DBI_RANGE) => dbi_n_out,
        data_o(DELAY_DQ_RANGE) => raw_data_o,
        data_o(DELAY_DBI_RANGE) => raw_dbi_n_o
    );

    -- Perform DBI processing where appropriate
    dbi : entity work.gddr6_phy_dbi port map (
        clk_i => clk_i,

        enable_dbi_i => enable_dbi_i,

        data_out_i => data_i,
        dbi_n_out_o => dbi_n_out,
        data_out_o => data_out,

        data_in_i => data_in,
        dbi_n_in_i => dbi_n_in,
        data_in_o => data_o,

        enable_training_i => train_dbi_i,
        train_dbi_n_i => dbi_n_i,
        train_dbi_n_o => dbi_n_o
    );


    -- Separate CRC calculations for incoming and outgoing data, but only one of
    -- them is useful at any time
    write_crc : entity work.gddr6_phy_crc port map (
        clk_i => clk_i,
        data_i => data_out,
        dbi_n_i => dbi_n_out,
        edc_o => edc_write_o
    );

    read_crc : entity work.gddr6_phy_crc port map (
        clk_i => clk_i,
        data_i => data_in,
        dbi_n_i => dbi_n_in,
        edc_o => edc_read_o
    );

    -- Just pass EDC from memory straight through
    edc_in_o <= edc_in;
end;
