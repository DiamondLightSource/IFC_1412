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
--      gddr6_phy_bitslices         Bitslice generation
--          gddr6_phy_byte              Generates a pair of nibbles
--              gddr6_phy_nibble            Generates complete IO nibble
--                  BITSLICE_CONTROL
--                  TX_BITSLICE_TRI
--                  RXTX_BITSLICE
--          gddr6_phy_dq_remap          Maps signals to bitslices
--      gddr6_phy_dq                DQ bus generation
--          gddr6_phy_bitslip           WCK data phase correction
--          gddr6_phy_map_dbi           Byte remapping and DBI correction
--          gddr6_phy_crc               CRC calculation on data on the wire
--              gddr6_phy_crc_core          CRC calculation
--      gddr6_phy_delay_control     Control of delay interface

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_phy_defs.all;

entity gddr6_phy is
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
        phy_setup_i : in phy_setup_t;
        phy_status_o : out phy_status_t;

        -- --------------------------------------------------------------------
        -- Delay control interface
        -- The address map here is defined in gddr6_register_defines.in
        setup_delay_i : in setup_delay_t;
        setup_delay_o : out setup_delay_result_t;

        -- --------------------------------------------------------------------
        -- CA
        -- Bit 3 in the second tick, ca_i(1)(3), can be overridden by ca3_i.
        -- To allow this set ca_i(1)(3) to '0', then ca3_i(n) will be used.
        ca_i : in vector_array(0 to 1)(9 downto 0);
        ca3_i : in std_ulogic_vector(0 to 3);
        -- Clock enable, held low during normal operation
        cke_n_i : in std_ulogic;

        -- --------------------------------------------------------------------
        -- DQ
        -- Data is transferred in a burst of 128 bytes over two ticks, and so is
        -- organised here as an array of 64 bytes, or 512 bits.
        data_i : in std_ulogic_vector(511 downto 0);
        data_o : out std_ulogic_vector(511 downto 0);
        -- Due to an extra delay in the BITSLICE output stages output_enable_i
        -- must be presented 1 CK tick earlier than data_i.
        output_enable_i : in std_ulogic;
        -- DBI training support.  Input dbi_n_i is ignored unless
        -- phy_setup_i.train_dbi is set
        dbi_n_i : in vector_array(7 downto 0)(7 downto 0);
        dbi_n_o : out vector_array(7 downto 0)(7 downto 0);
        -- Two calculations are presented on the EDC pins here.  edc_in_o is the
        -- value received from the memory, each 8-bit value is the CRC for one
        -- tick of data for 8 lanes.  edc_out_o is the corresponding internally
        -- calculated value, either for incoming data or for outgoing data as
        -- selected by output_enable_i.
        edc_in_o : out vector_array(7 downto 0)(7 downto 0);
        edc_out_o : out vector_array(7 downto 0)(7 downto 0);

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
    -- Have tried 300 MHz, but cannot get timing closure of BITSLICE IOs!
    constant CK_FREQUENCY : real := 250.0;
    constant REFCLK_FREQUENCY : real := 8.0 * CK_FREQUENCY;

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

    -- Status readbacks
    signal ck_unlock : std_ulogic;
    signal fifo_ok : std_ulogic_vector(0 to 1);

    -- Other clocks, resets, controls
    signal phy_clk : std_ulogic_vector(0 to 1);
    signal riu_clk : std_ulogic;
    signal ck_clk_delay : std_ulogic;
    signal bitslice_reset : std_ulogic;
    signal dly_ready : std_ulogic;
    signal vtc_ready : std_ulogic;
    signal enable_control_vtc : std_ulogic;
    signal enable_bitslice_control : std_ulogic;

    -- Signals to/from bitslices before alignment and processing
    signal raw_data_out : vector_array(63 downto 0)(7 downto 0);
    signal raw_data_in : vector_array(63 downto 0)(7 downto 0);
    signal raw_dbi_n_out : vector_array(7 downto 0)(7 downto 0);
    signal raw_dbi_n_in : vector_array(7 downto 0)(7 downto 0);
    signal raw_edc_in : vector_array(7 downto 0)(7 downto 0);

    -- Delay controls and readbacks
    signal delay_control : delay_control_t;
    signal delay_readbacks : delay_readbacks_t;
    signal bitslip_readbacks : unsigned_array(71 downto 0)(2 downto 0);

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
        ck_clk_delay_o => ck_clk_delay,

        ck_reset_i => ck_reset_i,
        ck_clk_ok_o => ck_clk_ok_o,
        ck_unlock_o => ck_unlock,

        bitslice_reset_o => bitslice_reset,
        dly_ready_i => dly_ready,
        vtc_ready_i => vtc_ready,
        enable_control_vtc_o => enable_control_vtc,
        enable_bitslice_control_o => enable_bitslice_control
    );


    -- CA generation
    ca : entity work.gddr6_phy_ca generic map (
        REFCLK_FREQUENCY => REFCLK_FREQUENCY
    ) port map (
        ck_clk_i => ck_clk,
        ck_clk_delay_i => ck_clk_delay,

        bitslice_reset_i => bitslice_reset,
        sg_resets_n_i => phy_setup_i.sg_resets_n,
        enable_cabi_i => phy_setup_i.enable_cabi,
        fudge_sticky_ca6_i => phy_setup_i.fudge_sticky_ca6,

        ca_i => ca_i,
        ca3_i => ca3_i,
        cke_n_i => cke_n_i,

        io_sg_resets_n_o => io_sg_resets_n_out,
        io_ca_o => io_ca_out,
        io_ca3_o => io_ca3_out,
        io_cabi_n_o => io_cabi_n_out,
        io_cke_n_o => io_cke_n_out
    );


    -- Bitslices.  This does the heavy lifting of bitslice generation
    bitslices : entity work.gddr6_phy_bitslices generic map (
        REFCLK_FREQUENCY => REFCLK_FREQUENCY
    ) port map (
        phy_clk_i => phy_clk,       -- Fast data transmit clock from PLL
        wck_i => io_wck_in,         -- WCK for receive clock from edge pins
        ck_clk_i => ck_clk,         -- Fabric clock for bitslice interface
        riu_clk_i => riu_clk,       -- Internal bitslice and delay control clock

        bitslice_reset_i => bitslice_reset,
        enable_control_vtc_i => enable_control_vtc,
        enable_bitslice_control_i => enable_bitslice_control,
        dly_ready_o => dly_ready,
        vtc_ready_o => vtc_ready,
        reset_fifo_i => phy_setup_i.reset_fifo,
        fifo_ok_o => fifo_ok,

        output_enable_i => output_enable_i,
        data_i => raw_data_out,
        data_o => raw_data_in,
        dbi_n_i => raw_dbi_n_out,
        dbi_n_o => raw_dbi_n_in,
        edc_o => raw_edc_in,
        edc_i => '1',           -- Configure memory for x1 mode during reset
        edc_t_i => phy_setup_i.edc_tri,

        delay_control_i => delay_control,
        delay_readbacks_o => delay_readbacks,

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


    -- Align data to and from bitslices
    dq : entity work.gddr6_phy_dq generic map (
        REFCLK_FREQUENCY => REFCLK_FREQUENCY
    ) port map (
        clk_i => ck_clk,

        edc_delay_i => phy_setup_i.edc_delay,
        enable_dbi_i => phy_setup_i.enable_dbi,
        train_dbi_i => phy_setup_i.train_dbi,
        delay_control_i => delay_control,
        bitslip_delay_o => bitslip_readbacks,

        raw_data_o => raw_data_out,
        raw_data_i => raw_data_in,
        raw_dbi_n_o => raw_dbi_n_out,
        raw_dbi_n_i => raw_dbi_n_in,
        raw_edc_i => raw_edc_in,

        output_enable_i => output_enable_i,
        data_o => data_o,
        data_i => data_i,
        dbi_n_o => dbi_n_o,
        dbi_n_i => dbi_n_i,
        edc_in_o => edc_in_o,
        edc_out_o => edc_out_o
    );


    delay : entity work.gddr6_phy_delay_control port map (
        clk_i => ck_clk,

        setup_i => setup_delay_i,
        setup_o => setup_delay_o,
        disable_vtc_i => phy_setup_i.disable_vtc,

        delay_control_o => delay_control,
        delay_i => delay_readbacks,
        bitslip_i => bitslip_readbacks
    );


    -- Status readbacks
    phy_status_o <= (
        ck_unlock => ck_unlock,
        fifo_ok => fifo_ok
    );
end;
