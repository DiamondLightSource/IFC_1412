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
--          BUFG
--          PLLE3_BASE
--          sync_bit
--      gddr6_phy_ca                CA generation
--          ODDRE1
--          ODELAYE1
--      gddr6_phy_dq                DQ bus generation
--          gddr6_phy_byte              Generates a pair of nibbles
--              gddr6_phy_nibble            Generates complete IO nibble
--                  BITSLICE_CONTROL
--                  TX_BITSLICE_TRI
--                  RXTX_BITSLICE
--          gddr6_phy_dq_remap          Maps signals to bitslices
--          gddr6_phy_bitslip           WCK data phase correction
--          gddr6_phy_map_dbi           Byte remapping and DBI correction
--          gddr6_phy_crc               CRC calculation on data on the wire
--              gddr6_phy_crc_core          CRC calculation
--      gddr6_phy_delay_control     Control of delay interface

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity gddr6_phy is
    generic (
        CK_FREQUENCY : real := 250.0;       -- 250.0 or 300.0 MHz
        CALIBRATE_DELAY : boolean := false; -- Enables use of DELAY_FORMAT=TIME
        INITIAL_DELAY : natural := 0
    );
    port (
        -- CK associated reset, hold this high until SG12_CK is valid.  All IOs
        -- are held in reset until CK is good.  This signal is asynchronous
        ck_reset_i : in std_ulogic;
        -- This is asserted on completion of reset synchronously with ck_clk_o
        -- but is driven low directly in response to ck_reset_i.
        ck_clk_ok_o : out std_ulogic;

        -- Clock from CK input.  All controls on this interface are synchronous
        -- to this clock except for ck_reset_i and ck_clk_ok_o which are
        -- treated as asynchronous.
        ck_clk_o : out std_ulogic;

        -- --------------------------------------------------------------------
        -- Miscellaneous controls

        -- This is asserted for one tick immediately after relocking if the CK
        -- PLL unlocks.
        ck_unlock_o : out std_ulogic;
        -- Can be used to hold the RX FIFO in reset
        reset_fifo_i : in std_ulogic_vector(0 to 1);
        -- This indicates that FIFO reset has been successful, and will go low
        -- if FIFO underflow or overflow is detected.
        fifo_ok_o : out std_ulogic_vector(0 to 1);

        -- Directly driven resets to the two GDDR6 devices.  Should be held low
        -- until ca_i has been properly set for configuration options.
        sg_resets_n_i : in std_ulogic_vector(0 to 1);

        -- Data bus inversion enables for CA and DQ interfaces
        enable_cabi_i : in std_ulogic;
        enable_dbi_i : in std_ulogic;
        -- If this flag is set then DBI is captured as edc_out_o
        capture_dbi_i : in std_ulogic;
        -- This delay is used to align data_o with data_i so that edc_out_o can
        -- be computed correctly
        edc_delay_i : in unsigned(4 downto 0);

        -- --------------------------------------------------------------------
        -- CA
        -- Bit 3 in the second tick, ca_i(1)(3), can be overridden by ca3_i.
        -- To allow this set ca_i(1)(3) to '0', then ca3_i(n) will be used.
        ca_i : in vector_array(0 to 1)(9 downto 0);
        ca3_i : in std_ulogic_vector(0 to 3);
        -- Clock enable, held low during normal operation
        cke_n_i : in std_ulogic_vector(0 to 1);

        -- --------------------------------------------------------------------
        -- DQ
        -- Data is transferred in a burst of 128 bytes over two ticks, and so is
        -- organised here as an array of 64 bytes, or 512 bits.
        data_i : in std_ulogic_vector(511 downto 0);
        data_o : out std_ulogic_vector(511 downto 0);
        -- Due to an extra delay in the BITSLICE output stages output_enable_i
        -- must be presented 1 CK tick earlier than data_i.
        output_enable_i : in std_ulogic;
        -- Two calculations are presented on the EDC pins here.  edc_in_o is the
        -- value received from the memory, each 8-bit value is the CRC for one
        -- tick of data for 8 lanes.  edc_out_o is the corresponding internally
        -- calculated value, either for incoming data or for outgoing data, as
        -- selected by output_enable_i, unless capture_dbi_i is set.
        edc_in_o : out vector_array(7 downto 0)(7 downto 0);
        edc_out_o : out vector_array(7 downto 0)(7 downto 0);
        -- Must be held low during SG reset, high during normal operation
        edc_t_i : in std_ulogic;

        -- --------------------------------------------------------------------
        -- Delay control interface
        -- The address map here is defined in gddr6_register_defines.in
        delay_address_i : in unsigned(7 downto 0);
        delay_i : in unsigned(8 downto 0);
        delay_up_down_n_i : in std_ulogic;
        delay_byteslip_i : in std_ulogic;
        delay_read_write_n_i : in std_ulogic;
        -- Delay readback for supported delays (IDELAY and ODELAY delays)
        delay_o : out unsigned(8 downto 0);
        delay_strobe_i : in std_ulogic;
        delay_ack_o : out std_ulogic;
        -- Individual delay resets.  These must be held for several ticks to
        -- take effect
        delay_reset_ca_i : in std_ulogic;       -- Reset all CA delays to zero
        delay_reset_dq_rx_i : in std_ulogic;    -- Reset all DQ RX delays
        delay_reset_dq_tx_i : in std_ulogic;    -- Reset all DQ TX delays

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
    constant REFCLK_FREQUENCY : real := 4.0 * CK_FREQUENCY;

    -- Pads with IO buffers
    -- Clocks and reset
    signal io_ck_in : std_ulogic;
    signal io_wck_in : std_ulogic_vector(0 to 1);
    signal io_sg_resets_n_out : std_ulogic_vector(0 to 1);
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
    signal io_edc_out : std_ulogic_vector(7 downto 0);
    signal io_edc_t_out : std_ulogic_vector(7 downto 0);

    signal bitslice_patch : std_ulogic_vector(0 to 0);

    -- A clock for use elsewhere cannot be assigned, only associated, as
    -- assigning produces a VHDL Delta cycle difference on the assigned clock,
    -- resulting in skewed clocks in simulation.
    alias ck_clk : std_ulogic is ck_clk_o;

    -- Other clocks, resets, controls
    signal phy_clk : std_ulogic_vector(0 to 1);
    signal riu_clk : std_ulogic;
    signal bitslice_reset : std_ulogic;
    signal dly_ready : std_ulogic;
    signal vtc_ready : std_ulogic;
    signal enable_control_vtc : std_ulogic;
    signal enable_bitslice_vtc : std_ulogic;

    -- Delay controls
    signal delay_up_down_n : std_ulogic;
    -- Delay strobes
    signal ca_tx_delay_ce : std_ulogic_vector(15 downto 0);
    signal dq_rx_delay_ce : std_ulogic_vector(63 downto 0);
    signal dq_tx_delay_ce : std_ulogic_vector(63 downto 0);
    signal dq_rx_byteslip : std_ulogic_vector(63 downto 0);
    signal dbi_rx_delay_ce : std_ulogic_vector(7 downto 0);
    signal dbi_tx_delay_ce : std_ulogic_vector(7 downto 0);
    signal dbi_rx_byteslip : std_ulogic_vector(7 downto 0);
    signal edc_rx_delay_ce : std_ulogic_vector(7 downto 0);
    signal edc_rx_byteslip : std_ulogic_vector(7 downto 0);
    -- DQ bitslip
    signal bitslip_delay : unsigned(2 downto 0);
    signal bitslip_address : unsigned(6 downto 0);
    signal bitslip_strobe : std_ulogic;
    -- Individual delay readbacks
    signal delay_dq_rx : vector_array(63 downto 0)(8 downto 0);
    signal delay_dq_tx : vector_array(63 downto 0)(8 downto 0);
    signal delay_dbi_rx : vector_array(7 downto 0)(8 downto 0);
    signal delay_dbi_tx : vector_array(7 downto 0)(8 downto 0);
    signal delay_edc_rx : vector_array(7 downto 0)(8 downto 0);
    signal delay_ca_tx : vector_array(15 downto 0)(8 downto 0);

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
        io_sg_resets_n_i => io_sg_resets_n_out,

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
        io_edc_i => io_edc_out,
        io_edc_t_i => io_edc_t_out
    );


    -- Clocks and resets
    clocking : entity work.gddr6_phy_clocking generic map (
        CK_FREQUENCY => CK_FREQUENCY
    ) port map (
        io_ck_i => io_ck_in,

        phy_clk_o => phy_clk,
        ck_clk_o => ck_clk,
        riu_clk_o => riu_clk,

        ck_reset_i => ck_reset_i,
        ck_clk_ok_o => ck_clk_ok_o,
        ck_unlock_o => ck_unlock_o,

        bitslice_reset_o => bitslice_reset,
        dly_ready_i => dly_ready,
        vtc_ready_i => vtc_ready,
        enable_control_vtc_o => enable_control_vtc
    );


    -- CA generation
    ca : entity work.gddr6_phy_ca generic map (
        CALIBRATE_DELAY => CALIBRATE_DELAY,
        INITIAL_DELAY => INITIAL_DELAY,
        REFCLK_FREQUENCY => REFCLK_FREQUENCY
    ) port map (
        ck_clk_i => ck_clk,
        reset_i => bitslice_reset,
        sg_resets_n_i => sg_resets_n_i,

        enable_cabi_i => enable_cabi_i,

        ca_i => ca_i,
        ca3_i => ca3_i,
        cke_n_i => cke_n_i,

        delay_rst_i => delay_reset_ca_i,
        delay_inc_i => delay_up_down_n,
        delay_ce_i => ca_tx_delay_ce,
        delay_o => delay_ca_tx,

        io_sg_resets_n_o => io_sg_resets_n_out,
        io_ca_o => io_ca_out,
        io_ca3_o => io_ca3_out,
        io_cabi_n_o => io_cabi_n_out,
        io_cke_n_o => io_cke_n_out
    );


    -- Data receive and transmit
    dq : entity work.gddr6_phy_dq generic map (
        CALIBRATE_DELAY => CALIBRATE_DELAY,
        INITIAL_DELAY => INITIAL_DELAY,
        REFCLK_FREQUENCY => REFCLK_FREQUENCY
    ) port map (
        phy_clk_i => phy_clk,       -- Fast data transmit clock from PLL
        wck_i => io_wck_in,         -- WCK for receive clock from edge pins
        ck_clk_i => ck_clk,         -- Fabric clock for bitslice interface
        riu_clk_i => riu_clk,       -- Internal bitslice and delay control clock

        bitslice_reset_i => bitslice_reset,
        dly_ready_o => dly_ready,
        vtc_ready_o => vtc_ready,
        enable_control_vtc_i => enable_control_vtc,
        enable_bitslice_vtc_i => enable_bitslice_vtc,
        reset_fifo_i => reset_fifo_i,
        fifo_ok_o => fifo_ok_o,
        capture_dbi_i => capture_dbi_i,
        edc_delay_i => edc_delay_i,
        enable_dbi_i => enable_dbi_i,

        data_o => data_o,
        data_i => data_i,
        output_enable_i => output_enable_i,
        edc_in_o => edc_in_o,
        edc_out_o => edc_out_o,
        edc_i => '1',           -- Configures memory for x1 mode during reset
        edc_t_i => edc_t_i,

        delay_up_down_n_i => delay_up_down_n,
        dq_rx_delay_ce_i => dq_rx_delay_ce,
        dq_tx_delay_ce_i => dq_tx_delay_ce,
        dq_rx_byteslip_i => dq_rx_byteslip,
        dbi_rx_delay_ce_i => dbi_rx_delay_ce,
        dbi_tx_delay_ce_i => dbi_tx_delay_ce,
        dbi_rx_byteslip_i => dbi_rx_byteslip,
        edc_rx_delay_ce_i => edc_rx_delay_ce,
        edc_rx_byteslip_i => edc_rx_byteslip,

        reset_rx_delay_i => delay_reset_dq_rx_i,
        reset_tx_delay_i => delay_reset_dq_tx_i,

        dq_rx_delay_o => delay_dq_rx,
        dq_tx_delay_o => delay_dq_tx,
        dbi_rx_delay_o => delay_dbi_rx,
        dbi_tx_delay_o => delay_dbi_tx,
        edc_rx_delay_o => delay_edc_rx,

        bitslip_delay_i => bitslip_delay,
        bitslip_address_i => bitslip_address,
        bitslip_strobe_i => bitslip_strobe,

        io_dq_o => io_dq_out,
        io_dq_i => io_dq_in,
        io_dq_t_o => io_dq_t_out,
        io_dbi_n_o => io_dbi_n_out,
        io_dbi_n_i => io_dbi_n_in,
        io_dbi_n_t_o => io_dbi_n_t_out,
        io_edc_i => io_edc_in,
        io_edc_o => io_edc_out,
        io_edc_t_o => io_edc_t_out,

        bitslice_patch_i => bitslice_patch
    );

    -- Pin SG12_CK occupies the space for bitslice 2:0 which we have to
    -- instantiate, this link helps to locate the bitslice.
    bitslice_patch <= (0 => io_ck_in);


    delay : entity work.gddr6_phy_delay_control generic map (
        CALIBRATE_DELAY => CALIBRATE_DELAY
    ) port map (
        ck_clk_i => ck_clk,

        delay_address_i => delay_address_i,
        delay_i => delay_i,
        delay_up_down_n_i => delay_up_down_n_i,
        byteslip_i => delay_byteslip_i,
        read_write_n_i => delay_read_write_n_i,
        delay_o => delay_o,
        strobe_i => delay_strobe_i,
        ack_o => delay_ack_o,

        delay_up_down_n_o => delay_up_down_n,

        ca_tx_delay_ce_o => ca_tx_delay_ce,
        dq_rx_delay_ce_o => dq_rx_delay_ce,
        dq_tx_delay_ce_o => dq_tx_delay_ce,
        dq_rx_byteslip_o => dq_rx_byteslip,
        dbi_rx_delay_ce_o => dbi_rx_delay_ce,
        dbi_tx_delay_ce_o => dbi_tx_delay_ce,
        dbi_rx_byteslip_o => dbi_rx_byteslip,
        edc_rx_delay_ce_o => edc_rx_delay_ce,
        edc_rx_byteslip_o => edc_rx_byteslip,

        bitslip_address_o => bitslip_address,
        bitslip_delay_o => bitslip_delay,
        bitslip_strobe_o => bitslip_strobe,

        delay_dq_rx_i => delay_dq_rx,
        delay_dq_tx_i => delay_dq_tx,
        delay_dbi_rx_i => delay_dbi_rx,
        delay_dbi_tx_i => delay_dbi_tx,
        delay_edc_rx_i => delay_edc_rx,
        delay_ca_tx_i => delay_ca_tx,

        enable_bitslice_vtc_o => enable_bitslice_vtc
    );
end;
