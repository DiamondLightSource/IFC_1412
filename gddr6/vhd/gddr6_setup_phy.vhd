-- Encapsulation of setup & phy together
--
-- During configuration the CA and DQ interface is controlled through the setup
-- register interface.  After setup is complete this interface is directly
-- connected to the memory controller.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.register_defs.all;
use work.gddr6_register_defines.all;

entity gddr6_setup_phy is
    generic (
        CK_FREQUENCY : real := 250.0;
        -- Delay readback is quite expensive in terms of fabric, so is optional
        ENABLE_DELAY_READBACK : boolean := false
    );
    port (
        reg_clk_i : in std_ulogic;      -- Register interface only
        ck_clk_o : out std_ulogic;      -- Memory controller only

        -- --------------------------------------------------------------------
        -- Register interface for initial setup on reg_clk_i
        write_strobe_i : in std_ulogic_vector(GDDR6_REGS_RANGE);
        write_data_i : in reg_data_array_t(GDDR6_REGS_RANGE);
        write_ack_o : out std_ulogic_vector(GDDR6_REGS_RANGE);
        read_strobe_i : in std_ulogic_vector(GDDR6_REGS_RANGE);
        read_data_o : out reg_data_array_t(GDDR6_REGS_RANGE);
        read_ack_o : out std_ulogic_vector(GDDR6_REGS_RANGE);

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
        output_enable_i : in std_ulogic;
        -- Two calculations are presented on the EDC pins here.  edc_in_o is the
        -- value received from the memory, each 8-bit value is the CRC for one
        -- tick of data for 8 lanes.  edc_out_o is the corresponding internally
        -- calculated value, either for incoming data or for outgoing data, as
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

architecture arch of gddr6_setup_phy is
    alias ck_clk : std_ulogic is ck_clk_o;
    signal ck_clk_ok : std_ulogic;

    signal setup_ca : vector_array(0 to 1)(9 downto 0);
    signal setup_ca3 : std_ulogic_vector(0 to 3);
    signal setup_cke_n : std_ulogic;
    signal setup_output_enable : std_ulogic;
    signal setup_data_in : std_ulogic_vector(511 downto 0);
    signal setup_data_out : std_ulogic_vector(511 downto 0);
    signal setup_edc_in : vector_array(7 downto 0)(7 downto 0);
    signal setup_edc_out : vector_array(7 downto 0)(7 downto 0);

    signal phy_ca : vector_array(0 to 1)(9 downto 0);
    signal phy_ca3 : std_ulogic_vector(0 to 3);
    signal phy_cke_n : std_ulogic;
    signal phy_output_enable : std_ulogic := '0';
    signal phy_data_in : std_ulogic_vector(511 downto 0);
    signal phy_data_out : std_ulogic_vector(511 downto 0);
    signal phy_edc_in : vector_array(7 downto 0)(7 downto 0);
    signal phy_edc_out : vector_array(7 downto 0)(7 downto 0);

    signal delay_address : unsigned(7 downto 0);
    signal delay : unsigned(7 downto 0);
    signal delay_up_down_n : std_ulogic;
    signal delay_strobe : std_ulogic;
    signal delay_ack : std_ulogic;

    signal delay_reset_ca : std_ulogic;
    signal delay_reset_dq_rx : std_ulogic;
    signal delay_reset_dq_tx : std_ulogic;

    signal read_delay_address : unsigned(7 downto 0);
    signal read_delay : unsigned(8 downto 0);

    signal ck_reset : std_ulogic;
    signal ck_unlock : std_ulogic;
    signal reset_fifo : std_ulogic_vector(0 to 1);
    signal fifo_ok : std_ulogic_vector(0 to 1);
    signal sg_resets_n : std_ulogic_vector(0 to 1);
    signal enable_cabi : std_ulogic;
    signal enable_dbi : std_ulogic;

    signal enable_controller : std_ulogic;

begin
    setup : entity work.gddr6_setup generic map (
        ENABLE_DELAY_READBACK => ENABLE_DELAY_READBACK
    ) port map (
        reg_clk_i => reg_clk_i,

        write_strobe_i => write_strobe_i,
        write_data_i => write_data_i,
        write_ack_o => write_ack_o,
        read_strobe_i => read_strobe_i,
        read_data_o => read_data_o,
        read_ack_o => read_ack_o,

        ck_clk_i => ck_clk,
        ck_clk_ok_i => ck_clk_ok,

        phy_ca_o => setup_ca,
        phy_ca3_o => setup_ca3,
        phy_cke_n_o => setup_cke_n,
        phy_output_enable_o => setup_output_enable,
        phy_data_o => setup_data_out,
        phy_data_i => setup_data_in,
        phy_edc_in_i => setup_edc_in,
        phy_edc_out_i => setup_edc_out,

        delay_address_o => delay_address,
        delay_o => delay,
        delay_up_down_n_o => delay_up_down_n,
        delay_strobe_o => delay_strobe,
        delay_ack_i => delay_ack,
        delay_reset_ca_o => delay_reset_ca,
        delay_reset_dq_rx_o => delay_reset_dq_rx,
        delay_reset_dq_tx_o => delay_reset_dq_tx,
        read_delay_address_o => read_delay_address,
        read_delay_i => read_delay,

        ck_reset_o => ck_reset,
        ck_unlock_i => ck_unlock,
        reset_fifo_o => reset_fifo,
        fifo_ok_i => fifo_ok,
        sg_resets_n_o => sg_resets_n,
        enable_cabi_o => enable_cabi,
        enable_dbi_o => enable_dbi,

        enable_controller_o => enable_controller
    );


    phy : entity work.gddr6_phy generic map (
        CK_FREQUENCY => CK_FREQUENCY
    ) port map (
        ck_clk_o => ck_clk,

        ck_reset_i => ck_reset,
        ck_clk_ok_o => ck_clk_ok,
        ck_unlock_o => ck_unlock,
        reset_fifo_i => reset_fifo,
        fifo_ok_o => fifo_ok,

        sg_resets_n_i => sg_resets_n,

        ca_i => phy_ca,
        ca3_i => phy_ca3,
        cke_n_i => phy_cke_n,
        enable_cabi_i => enable_cabi,

        data_i => phy_data_out,
        data_o => phy_data_in,
        output_enable_i => phy_output_enable,
        enable_dbi_i => enable_dbi,
        edc_in_o => phy_edc_in,
        edc_out_o => phy_edc_out,

        delay_address_i => delay_address,
        delay_i => delay,
        delay_up_down_n_i => delay_up_down_n,
        delay_strobe_i => delay_strobe,
        delay_ack_o => delay_ack,
        delay_reset_ca_i => delay_reset_ca,
        delay_reset_dq_rx_i => delay_reset_dq_rx,
        delay_reset_dq_tx_i => delay_reset_dq_tx,
        read_delay_address_i => read_delay_address,
        read_delay_o => read_delay,

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
        pad_SG2_EDC_B_io => pad_SG2_EDC_B_io
    );


    -- Setup and controller MUX.  Not registered at present, but this can be
    -- done if required.
    process (ck_clk) begin
        if rising_edge(ck_clk) then
            if enable_controller then
                phy_ca <= ca_i;
                phy_ca3 <= ca3_i;
                phy_cke_n <= cke_n_i;
                phy_data_out <= data_i;
                phy_output_enable <= output_enable_i;
            else
                phy_ca <= setup_ca;
                phy_ca3 <= setup_ca3;
                phy_cke_n <= setup_cke_n;
                phy_data_out <= setup_data_out;
                phy_output_enable <= setup_output_enable;
            end if;
            data_o <= phy_data_in;
            edc_in_o <= phy_edc_in;
            edc_out_o <= phy_edc_out;
            setup_data_in <= phy_data_in;
            setup_edc_in <= phy_edc_in;
            setup_edc_out <= phy_edc_out;
        end if;
    end process;
end;
