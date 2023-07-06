-- Top level interface to GDDR6 IO
--
-- Entity structure as follows:
--
--  gddr6_phy
--      gddr6_phy_io                Map pads to IO buffers
--          ibufds_array                Arrays of IBUFDS, IBUF, OBUF, IOBUF
--          ibuf_array                  respectively.  All IO buffers explicitly
--          obuf_array                  instantiated
--          iobuf_array
--      gddr6_phy_clocking          Top level clocking and control
--          (not yet implemented)
--      gddr6_phy_ca                CA generation
--          ODDRE1
--          ODELAYE3
--      gddr6_phy_dq                DQ bus generation
--          gddr6_phy_byte              Generates a pair of nibbles
--              gddr6_phy_nibble            Generates complete IO nibble
--                  BITSLICE_CONTROL
--                  TX_BITSLICE_TRI
--                  RXTX_BITSLICE
--          gddr6_phy_map_data          Data remapping and DBI correction
--      gddr6_phy_delay_control     Register control of delays

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity gddr6_phy is
    port (
        -- --------------------------------------------------------------------
        -- Clocks reset and control
        --

        -- Directly driven resets to the two GDDR6 devices.  Should be held high
        -- until ca_i has been properly set for configuration options.
        sg_resets_i : in std_ulogic_vector(0 to 1);


        -- --------------------------------------------------------------------
        -- CA
        -- Bit 3 in the second tick, ca_i(1)(3), can be overridden by ca3_i.
        -- To allow this set ca_i(1)(3) to '0', then ca3_i(n) will be used.
        ca_i : in vector_array(0 to 1)(9 downto 0);
        ca3_i : in std_ulogic_vector(0 to 3);
        -- Clock enable, held low during normal operation
        cke_n_i : in std_ulogic;
        enable_cabi_i : in std_ulogic;
        -- Configuration driven onto edc pins at startup.  Otherwise edc_t_i
        -- be driven high so that edc_o can be read from the device.
        edc_i : in std_ulogic_vector(7 downto 0);
        edc_t_i : in std_ulogic;

        -- --------------------------------------------------------------------
        -- DQ
        -- Data is transferred in a burst of 128 bytes over two ticks, and so is
        -- organised here as an array of 64 bytes, or 512 bits.
        data_i : in std_ulogic_vector(511 downto 0);
        data_o : out std_ulogic_vector(511 downto 0);
        edc_o : out std_ulogic_vector(63 downto 0);
        dq_t_i : in std_ulogic;
        enable_dbi_i : in std_ulogic;

        -- --------------------------------------------------------------------
        -- Register Interface to Delays
        --  The current delay for the selected pin is returned synchronously
        -- with ack_o.  If write_i is set when strobe_i is pulsed the delay will
        -- be written and any updated delay is returned.
        --   Note that select_i, tx_rx_n_i, write_i, delay_i must all be held
        -- unchanged from strobe_i until ack_o
        delay_select_i : in unsigned(6 downto 0);   -- Select pin to update
        delay_rx_tx_n_i : in std_ulogic;            -- Select RX or TX*
        delay_write_i : in std_ulogic;              -- Select Write delay
        delay_i : in unsigned(8 downto 0);          -- Delay to write
        delay_o : out unsigned(8 downto 0);         -- Delay read on completion
        delay_strobe_i : in std_ulogic;             -- Start access
        delay_ack_o : out std_ulogic;               -- Strobed on completion

        -- --------------------------------------------------------------------
        -- GDDR pins
        pad_SG12_CK_P_i : in std_ulogic;
        pad_SG12_CK_N_i : in std_ulogic;
        pad_SG1_WCK_P_i : in std_ulogic;
        pad_SG1_WCK_N_i : in std_ulogic;
        pad_SG2_WCK_P_i : in std_ulogic;
        pad_SG2_WCK_N_i : in std_ulogic;
        pad_SG1_RESET_N_o : out std_ulogic;
        pad_SG2_RESET_N_o : out std_ulogic;
        pad_SG12_CKE_N_o : out std_ulogic;
        pad_SG12_CABI_N_o : out std_ulogic;
        pad_SG12_CAL_o : out std_ulogic_vector(2 downto 0);
        pad_SG1_CA3_A_o : out std_ulogic;
        pad_SG1_CA3_B_o : out std_ulogic;
        pad_SG2_CA3_A_o : out std_ulogic;
        pad_SG2_CA3_B_o : out std_ulogic;
        pad_SG12_CAU_o : out std_ulogic_vector(9 downto 4);
        pad_SG1_DQ_A_io : inout std_logic_vector(15 downto 0);
        pad_SG1_DQ_B_io : inout std_logic_vector(15 downto 0);
        pad_SG2_DQ_A_io : inout std_logic_vector(15 downto 0);
        pad_SG2_DQ_B_io : inout std_logic_vector(15 downto 0);
        pad_SG1_DBI_N_A_io : inout std_logic_vector(1 downto 0);
        pad_SG1_DBI_N_B_io : inout std_logic_vector(1 downto 0);
        pad_SG2_DBI_N_A_io : inout std_logic_vector(1 downto 0);
        pad_SG2_DBI_N_B_io : inout std_logic_vector(1 downto 0);
        pad_SG1_EDC_A_io : inout std_logic_vector(1 downto 0);
        pad_SG1_EDC_B_io : inout std_logic_vector(1 downto 0);
        pad_SG2_EDC_A_io : inout std_logic_vector(1 downto 0);
        pad_SG2_EDC_B_io : inout std_logic_vector(1 downto 0)
    );
end;

architecture arch of gddr6_phy is
    constant REFCLK_FREQUENCY : real := 2000.0;
    constant CA_ODELAY_PS : natural := 100;    -- Max is 1250

    -- Pads with IO buffers
    -- Clocks and reset
    signal io_ck_in : std_ulogic;
    signal io_wck_in : std_ulogic_vector(0 to 1);
    signal io_reset_n_out : std_ulogic_vector(0 to 1);
    -- CA
    signal io_ca_out : std_ulogic_vector(9 downto 0);
    signal io_ca3_out : std_ulogic_vector(0 to 3);
    signal io_cabi_n_out : std_ulogic;
    signal io_cke_n_out : std_ulogic;
    -- DQ
    signal io_dq_in : std_ulogic_vector(63 downto 0);
    signal io_dq_out : std_ulogic_vector(63 downto 0);
    signal io_dq_t_out : std_ulogic_vector(63 downto 0);
    signal io_dbi_n_in : std_ulogic_vector(7 downto 0);
    signal io_dbi_n_out : std_ulogic_vector(7 downto 0);
    signal io_dbi_n_t_out : std_ulogic_vector(7 downto 0);
    signal io_edc_in : std_ulogic_vector(7 downto 0);

    -- Clocks and resets
    signal pll_clk : std_ulogic_vector(0 to 1);
    signal clk : std_ulogic;
    signal reset : std_ulogic;
    signal sg_reset : std_ulogic_vector(0 to 1);
    signal dly_ready : std_ulogic;
    signal vtc_ready : std_ulogic;
    signal fifo_empty : std_ulogic;
    signal fifo_enable : std_ulogic;
    signal enable_control_vtc : std_ulogic;

    signal enable_cabi : std_ulogic;

    -- Delay control signals
    signal ca_enable_vtc : std_ulogic_vector(0 to 15);
    signal ca_load_delay : std_ulogic_vector(0 to 15);
    signal ca_read_delay : vector_array(0 to 15)(8 downto 0);
    signal dq_enable_vtc : std_ulogic_vector(0 to 95);
    signal dq_load_delay : std_ulogic_vector(0 to 95);
    signal dq_read_delay : vector_array(0 to 95)(8 downto 0);

    subtype DQ_DELAY_RANGE is natural range 0 to 95;
    subtype CA_DELAY_RANGE is natural range 96 to 111;

begin
    -- Map pads to IO buffers and gather related signals
    io : entity work.gddr6_phy_io port map (
        pad_SG12_CK_P_i => pad_SG12_CK_P_i,
        pad_SG12_CK_N_i => pad_SG12_CK_N_i,
        pad_SG1_WCK_P_i => pad_SG1_WCK_P_i,
        pad_SG1_WCK_N_i => pad_SG1_WCK_N_i,
        pad_SG2_WCK_P_i => pad_SG2_WCK_P_i,
        pad_SG2_WCK_N_i => pad_SG2_WCK_N_i,
        pad_SG1_RESET_N_o => pad_SG1_RESET_N_o,
        pad_SG2_RESET_N_o => pad_SG2_RESET_N_o,
        pad_SG12_CKE_N_o => pad_SG12_CKE_N_o,
        pad_SG12_CABI_N_o => pad_SG12_CABI_N_o,
        pad_SG12_CAL_o => pad_SG12_CAL_o,
        pad_SG1_CA3_A_o => pad_SG1_CA3_A_o,
        pad_SG1_CA3_B_o => pad_SG1_CA3_B_o,
        pad_SG2_CA3_A_o => pad_SG2_CA3_A_o,
        pad_SG2_CA3_B_o => pad_SG2_CA3_B_o,
        pad_SG12_CAU_o => pad_SG12_CAU_o,
        pad_SG1_DQ_A_io => pad_SG1_DQ_A_io,
        pad_SG1_DQ_B_io => pad_SG1_DQ_B_io,
        pad_SG2_DQ_A_io => pad_SG2_DQ_A_io,
        pad_SG2_DQ_B_io => pad_SG2_DQ_B_io,
        pad_SG1_DBI_N_A_io => pad_SG1_DBI_N_A_io,
        pad_SG1_DBI_N_B_io => pad_SG1_DBI_N_B_io,
        pad_SG2_DBI_N_A_io => pad_SG2_DBI_N_A_io,
        pad_SG2_DBI_N_B_io => pad_SG2_DBI_N_B_io,
        pad_SG1_EDC_A_io => pad_SG1_EDC_A_io,
        pad_SG1_EDC_B_io => pad_SG1_EDC_B_io,
        pad_SG2_EDC_A_io => pad_SG2_EDC_A_io,
        pad_SG2_EDC_B_io => pad_SG2_EDC_B_io,

        io_ck_o => io_ck_in,
        io_wck_o => io_wck_in,
        io_reset_n_i => io_reset_n_out,

        io_ca_i => io_ca_out,
        io_ca3_i => io_ca3_out,
        io_cabi_n_i => io_cabi_n_out,
        io_cke_n_i => io_cke_n_out,

        io_dq_i => io_dq_out,
        io_dq_o => io_dq_in,
        io_dq_t_i => io_dq_t_out,
        io_dbi_n_i => io_dbi_n_out,
        io_dbi_n_o => io_dbi_n_in,
        io_dbi_n_t_i => io_dbi_n_t_out,
        io_edc_o => io_edc_in,
        -- Note that the EDC output drive bypasses all the bitslice control, as
        -- this is only designed to be configured during reset configuration
        io_edc_i => edc_i,
        io_edc_t_i => (others => edc_t_i)
    );



--     clocking : entity work.gddr6_phy_clocking port map (


    ca : entity work.gddr6_phy_ca generic map (
        REFCLK_FREQUENCY => REFCLK_FREQUENCY,
        CA_ODELAY_PS => CA_ODELAY_PS
    ) port map (
        clk_i => clk,
        reset_i => reset,
        sg_resets_i => sg_resets_i,

        enable_cabi_i => enable_cabi_i,

        ca_i => ca_i,
        ca3_i => ca3_i,
        cke_n_i => cke_n_i,

        enable_vtc_i => ca_enable_vtc,
        load_delay_i => ca_load_delay,
        delay_i => std_ulogic_vector(delay_i),
        delay_o => ca_read_delay,

        io_reset_n_o => io_reset_n_out,
        io_ca_o => io_ca_out,
        io_ca3_o => io_ca3_out,
        io_cabi_n_o => io_cabi_n_out,
        io_cke_n_o => io_cke_n_out
    );


    dq : entity work.gddr6_phy_dq port map (
        pll_clk_i => pll_clk,
        reg_clk_i => clk,
        wck_i => io_wck_in,

        reset_i => reset,
        dly_ready_o => dly_ready,
        vtc_ready_o => vtc_ready,
        fifo_empty_o => fifo_empty,
        fifo_enable_i => fifo_enable,
        enable_control_vtc_i => enable_control_vtc,

        data_i => data_i,
        data_o => data_o,
        edc_o => edc_o,
        dq_t_i => dq_t_i,
        enable_dbi_i => enable_dbi_i,

        delay_i => std_ulogic_vector(delay_i),
        delay_rx_tx_n_i => delay_rx_tx_n_i,
        enable_vtc_i => dq_enable_vtc,
        load_delay_i => dq_load_delay,
        delay_o => dq_read_delay,

        io_dq_o => io_dq_out,
        io_dq_i => io_dq_in,
        io_dq_t_o => io_dq_t_out,
        io_dbi_n_o => io_dbi_n_out,
        io_dbi_n_i => io_dbi_n_in,
        io_dbi_n_t_o => io_dbi_n_t_out,
        io_edc_i => io_edc_in
    );


    delay_control : entity work.gddr6_phy_delay_control port map (
        clk_i => clk,

        delay_select_i => delay_select_i,
        delay_write_i => delay_write_i,
        delay_strobe_i => delay_strobe_i,
        delay_ack_o => delay_ack_o,
        delay_o => delay_o,

        enable_vtc_o(DQ_DELAY_RANGE) => dq_enable_vtc,
        enable_vtc_o(CA_DELAY_RANGE) => ca_enable_vtc,
        load_delay_o(DQ_DELAY_RANGE) => dq_load_delay,
        load_delay_o(CA_DELAY_RANGE) => ca_load_delay,
        read_delay_i(DQ_DELAY_RANGE) => dq_read_delay,
        read_delay_i(CA_DELAY_RANGE) => ca_read_delay
    );
end;
