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
--      gddr6_phy_dq                DQ bus generation
--          gddr6_phy_byte              Generates a pair of nibbles
--              gddr6_phy_nibble            Generates complete IO nibble
--                  BITSLICE_CONTROL
--                  TX_BITSLICE_TRI
--                  RXTX_BITSLICE
--          gddr6_phy_dq_remap          Maps signals to bitslices
--          gddr6_phy_bitslip           WCK data phase correction
--          gddr6_phy_map_dbi           Data remapping and DBI correction
--          gddr6_phy_crc               CRC calculation on data on the wire
--      gddr6_phy_riu_control       Control of RIU interface

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity gddr6_phy is
    generic (
        CK_FREQUENCY : real := 250.0    -- 250.0 or 300.0 MHz
    );
    port (
        -- --------------------------------------------------------------------
        -- Clocks reset and control

        -- Clock from CK input.  All CA and DQ signals are synchronous to this
        -- clock.
        ck_clk_o : out std_ulogic;
        -- Half frequency clock for register interface, synchronous with
        -- ck_clk_o.  The RIU interface uses this clock
        riu_clk_o : out std_ulogic;

        -- CK associated reset, hold this high until SG12_CK is valid.  All IOs
        -- are held in reset until CK is good.  This signal is asynchronous
        ck_reset_i : in std_ulogic;
        -- This is asserted on completion of reset synchronously with ck_clk_o
        -- but is driven low directly in response to ck_reset_i.
        ck_clk_ok_o : out std_ulogic;
        -- This is asserted for one tick immediately after relocking if the CK
        -- PLL unlocks.
        ck_unlock_o : out std_ulogic;
        -- Can be used to hold the RX FIFO in reset
        reset_fifo_i : in std_ulogic;
        -- This indicates that FIFO reset has been successful, and will go low
        -- if FIFO underflow or overflow is detected.
        fifo_ok_o : out std_ulogic;

        -- Directly driven resets to the two GDDR6 devices.  Should be held low
        -- until ca_i has been properly set for configuration options.
        sg_resets_n_i : in std_ulogic_vector(0 to 1);

        -- --------------------------------------------------------------------
        -- CA
        -- Bit 3 in the second tick, ca_i(1)(3), can be overridden by ca3_i.
        -- To allow this set ca_i(1)(3) to '0', then ca3_i(n) will be used.
        ca_i : in vector_array(0 to 1)(9 downto 0);
        ca3_i : in std_ulogic_vector(0 to 3);
        -- Clock enable, held low during normal operation
        cke_n_i : in std_ulogic;
        enable_cabi_i : in std_ulogic;

        -- --------------------------------------------------------------------
        -- DQ
        -- Data is transferred in a burst of 128 bytes over two ticks, and so is
        -- organised here as an array of 64 bytes, or 512 bits.
        data_i : in std_ulogic_vector(511 downto 0);
        data_o : out std_ulogic_vector(511 downto 0);
        dq_t_i : in std_ulogic;
        enable_dbi_i : in std_ulogic;
        -- Two calculations are presented on the EDC pins here.  edc_in_o is the
        -- value received from the memory, each 8-bit value is the CRC for one
        -- tick of data for 8 lanes.  edc_out_o is the corresponding internally
        -- calculated value, either for incoming data or for outgoing data, as
        -- selected by dq_t_i.
        edc_in_o : out vector_array(7 downto 0)(7 downto 0);
        edc_out_o : out vector_array(7 downto 0)(7 downto 0);

        -- --------------------------------------------------------------------
        -- Register Interface to bitslice
        -- Read or write the selected register, addressed as follows by
        -- riu_addr_i: bit 9 selects the bank, bits 8:7 the byte within the
        -- bank, bit 6 selects the nibble, bits 5:0 address the RIU register.
        --    All riu signals are clocked by riu_clk_o
        riu_addr_i : in unsigned(9 downto 0);
        riu_wr_data_i : in std_ulogic_vector(15 downto 0);
        riu_rd_data_o : out std_ulogic_vector(15 downto 0);
        riu_wr_en_i : in std_ulogic;
        riu_strobe_i : in std_ulogic;
        riu_ack_o : out std_ulogic;
        -- If the RIU stops responding this bit will be set on ack
        riu_error_o : out std_ulogic;
        -- If this is set a complete VTC handshake is performed
        riu_vtc_handshake_i : in std_ulogic;

        -- Bitslip control interface
        bitslip_delay_i : in unsigned(3 downto 0);
        bitslip_delay_address_i : in unsigned(6 downto 0);
        bitslip_delay_strobe_i : in std_ulogic;


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
    -- This is a somewhat arbitrary initial value used for time calibration.
    constant INITIAL_DELAY : natural := 500;    -- Max is 1250

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

    signal bitslice_patch : std_ulogic_vector(0 to 0);

    -- Clocks resets and controls
    signal pll_clk : std_ulogic_vector(0 to 1);
    signal reset : std_ulogic;
    signal dly_ready : std_ulogic;
    signal vtc_ready : std_ulogic;
    signal fifo_empty : std_ulogic;
    signal fifo_enable : std_ulogic;
    signal enable_control_vtc : std_ulogic;
    signal enable_bitslice_vtc : std_ulogic;

    -- A clock for use elsewhere cannot be assigned, only associated, as
    -- assigning produces a VHDL Delta cycle difference on the assigned clock,
    -- resulting in skewed clocks in simulation.
    alias ck_clk : std_ulogic is ck_clk_o;
    alias riu_clk : std_ulogic is riu_clk_o;

    -- RIU control signals
    signal riu_addr : unsigned(9 downto 0);
    signal riu_wr_data : std_ulogic_vector(15 downto 0);
    signal riu_rd_data : std_ulogic_vector(15 downto 0);
    signal riu_valid : std_ulogic;
    signal riu_wr_en : std_ulogic;

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
        io_edc_o => io_edc_in
    );


    -- Clocks and resets
    clocking : entity work.gddr6_phy_clocking generic map (
        CK_FREQUENCY => CK_FREQUENCY
    ) port map (
        ck_clk_o => ck_clk,
        riu_clk_o => riu_clk,

        ck_reset_i => ck_reset_i,
        ck_clk_ok_o => ck_clk_ok_o,
        ck_unlock_o => ck_unlock_o,

        io_ck_i => io_ck_in,
        pll_clk_o => pll_clk,

        reset_o => reset,
        dly_ready_i => dly_ready,
        vtc_ready_i => vtc_ready,
        enable_control_vtc_o => enable_control_vtc
    );


    -- CA generation
    ca : entity work.gddr6_phy_ca port map (
        clk_i => ck_clk,
        reset_i => reset,
        sg_resets_n_i => sg_resets_n_i,

        enable_cabi_i => enable_cabi_i,

        ca_i => ca_i,
        ca3_i => ca3_i,
        cke_n_i => cke_n_i,

        io_sg_resets_n_o => io_sg_resets_n_out,
        io_ca_o => io_ca_out,
        io_ca3_o => io_ca3_out,
        io_cabi_n_o => io_cabi_n_out,
        io_cke_n_o => io_cke_n_out
    );


    -- Data receive and transmit
    dq : entity work.gddr6_phy_dq generic map (
        REFCLK_FREQUENCY => REFCLK_FREQUENCY,
        INITIAL_DELAY => INITIAL_DELAY
    ) port map (
        pll_clk_i => pll_clk,
        wck_i => io_wck_in,
        ck_clk_i => ck_clk,

        reset_i => reset,
        dly_ready_o => dly_ready,
        vtc_ready_o => vtc_ready,
        reset_fifo_i => reset_fifo_i,
        fifo_ok_o => fifo_ok_o,
        enable_control_vtc_i => enable_control_vtc,
        enable_bitslice_vtc_i => enable_bitslice_vtc,

        data_i => data_i,
        data_o => data_o,
        dq_t_i => dq_t_i,
        enable_dbi_i => enable_dbi_i,
        edc_in_o => edc_in_o,
        edc_out_o => edc_out_o,

        riu_clk_i => riu_clk,
        riu_addr_i => riu_addr,
        riu_wr_data_i => riu_wr_data,
        riu_rd_data_o => riu_rd_data,
        riu_valid_o => riu_valid,
        riu_wr_en_i => riu_wr_en,

        bitslip_delay_i => bitslip_delay_i,
        bitslip_delay_address_i => bitslip_delay_address_i,
        bitslip_delay_strobe_i => bitslip_delay_strobe_i,

        io_dq_o => io_dq_out,
        io_dq_i => io_dq_in,
        io_dq_t_o => io_dq_t_out,
        io_dbi_n_o => io_dbi_n_out,
        io_dbi_n_i => io_dbi_n_in,
        io_dbi_n_t_o => io_dbi_n_t_out,
        io_edc_i => io_edc_in,

        bitslice_patch_i => bitslice_patch
    );

    -- Pin SG12_CK occupies the space for bitslice 2:0 which we have to
    -- instantiate, this link helps to locate the bitslice.
    bitslice_patch <= (0 => io_ck_in);


    -- Register interface to individual pin delays
    riu : entity work.gddr6_phy_riu_control port map (
        clk_i => riu_clk,

        riu_addr_i => riu_addr_i,
        riu_wr_data_i => riu_wr_data_i,
        riu_rd_data_o => riu_rd_data_o,
        riu_wr_en_i => riu_wr_en_i,
        riu_strobe_i => riu_strobe_i,
        riu_ack_o => riu_ack_o,
        riu_error_o => riu_error_o,
        riu_vtc_handshake_i => riu_vtc_handshake_i,

        riu_addr_o => riu_addr,
        riu_wr_data_o => riu_wr_data,
        riu_rd_data_i => riu_rd_data,
        riu_valid_i => riu_valid,
        riu_wr_en_o => riu_wr_en,
        enable_vtc_o => enable_bitslice_vtc
    );
end;
