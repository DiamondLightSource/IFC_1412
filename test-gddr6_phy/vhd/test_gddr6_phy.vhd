-- Top level test for gddr6 phy test

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.register_defines.all;

entity test_gddr6_phy is
    generic (
        CK_FREQUENCY : real := 250.0
    );
    port (
        clk_i : in std_ulogic;

        regs_write_strobe_i : in std_ulogic;
        regs_write_address_i : in unsigned(13 downto 0);
        regs_write_data_i : in std_ulogic_vector(31 downto 0);
        regs_write_ack_o : out std_ulogic;
        regs_read_strobe_i : in std_ulogic;
        regs_read_address_i : in unsigned(13 downto 0);
        regs_read_data_o : out std_ulogic_vector(31 downto 0);
        regs_read_ack_o : out std_ulogic;

        pad_LMK_CTL_SEL_o : out std_ulogic;
        pad_LMK_SCL_o : out std_ulogic;
        pad_LMK_SCS_L_o : out std_ulogic;
        pad_LMK_SDIO_io : inout std_logic;
        pad_LMK_RESET_L_o : out std_ulogic;
        pad_LMK_SYNC_io : inout std_logic;
        pad_LMK_STATUS_io : inout std_logic_vector(0 to 1);

        pad_SG12_CK_P_i : in std_ulogic;
        pad_SG12_CK_N_i : in std_ulogic;
        pad_SG1_WCK_P_i : in std_ulogic;
        pad_SG1_WCK_N_i : in std_ulogic;
        pad_SG2_WCK_P_i : in std_ulogic;
        pad_SG2_WCK_N_i : in std_ulogic;
        pad_SG1_RESET_N_o : out std_ulogic;
        pad_SG2_RESET_N_o : out std_ulogic;
        pad_SG12_CKE_N_o : out std_ulogic;
        pad_SG12_CAL_o : out std_ulogic_vector(2 downto 0);
        pad_SG1_CA3_A_o : out std_ulogic;
        pad_SG1_CA3_B_o : out std_ulogic;
        pad_SG2_CA3_A_o : out std_ulogic;
        pad_SG2_CA3_B_o : out std_ulogic;
        pad_SG12_CAU_o : out std_ulogic_vector(9 downto 4);
        pad_SG12_CABI_N_o : out std_ulogic;
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

architecture arch of test_gddr6_phy is
    -- System register wiring
    signal sys_write_strobe : std_ulogic_vector(SYS_REGS_RANGE);
    signal sys_write_data : reg_data_array_t(SYS_REGS_RANGE);
    signal sys_write_ack : std_ulogic_vector(SYS_REGS_RANGE);
    signal sys_read_strobe : std_ulogic_vector(SYS_REGS_RANGE);
    signal sys_read_data : reg_data_array_t(SYS_REGS_RANGE);
    signal sys_read_ack : std_ulogic_vector(SYS_REGS_RANGE);

    -- GDDR6 register wiring
    signal phy_write_strobe : std_ulogic_vector(PHY_REGS_RANGE);
    signal phy_write_data : reg_data_array_t(PHY_REGS_RANGE);
    signal phy_write_ack : std_ulogic_vector(PHY_REGS_RANGE);
    signal phy_read_strobe : std_ulogic_vector(PHY_REGS_RANGE);
    signal phy_read_data : reg_data_array_t(PHY_REGS_RANGE);
    signal phy_read_ack : std_ulogic_vector(PHY_REGS_RANGE);


    -- -------------------------------------------------------------------------

    -- LMK config and status
    signal lmk_command_select : std_ulogic;
    signal lmk_status : std_ulogic_vector(1 downto 0);
    signal lmk_reset : std_ulogic;
    signal lmk_sync : std_ulogic;

    -- SPI interface to LMK
    signal lmk_write_strobe : std_ulogic;
    signal lmk_write_ack : std_ulogic;
    signal lmk_read_write_n : std_ulogic;
    signal lmk_address : std_ulogic_vector(14 downto 0);
    signal lmk_data_in : std_ulogic_vector(7 downto 0);
    signal lmk_write_select : std_ulogic;
    signal lmk_read_strobe : std_ulogic;
    signal lmk_read_ack : std_ulogic;
    signal lmk_data_out : std_ulogic_vector(7 downto 0);

    -- SG clocking and reset control
    signal ck_clk : std_ulogic;
    signal riu_clk : std_ulogic;
    signal ck_reset : std_ulogic;
    signal raw_ck_clk_ok : std_ulogic;      -- Unsynchronised
    signal ck_clk_ok : std_ulogic;
    signal ck_unlock : std_ulogic;
    signal fifo_ok : std_ulogic;
    signal sg_resets : std_ulogic_vector(0 to 1);

    -- SG CA and initial EDC
    signal ca : vector_array(0 to 1)(9 downto 0);
    signal ca3 : std_ulogic_vector(0 to 3);
    signal cke_n : std_ulogic;
    signal enable_cabi : std_ulogic;

    -- SG DQ signals
    signal dq_data_in : std_ulogic_vector(511 downto 0);
    signal dq_data_out : std_ulogic_vector(511 downto 0);
    signal dq_t : std_ulogic;
    signal enable_dbi : std_ulogic;
    signal edc_in : vector_array(7 downto 0)(7 downto 0);
    signal edc_out : vector_array(7 downto 0)(7 downto 0);

    -- SG RIU control
    signal riu_addr : unsigned(9 downto 0);
    signal riu_wr_data : std_ulogic_vector(15 downto 0);
    signal riu_rd_data : std_ulogic_vector(15 downto 0);
    signal riu_wr_en : std_ulogic;
    signal riu_strobe : std_ulogic;
    signal riu_ack : std_ulogic;
    signal riu_error : std_ulogic;
    signal riu_vtc_handshake : std_ulogic;

    -- "Bitslip" control
    signal rx_slip : unsigned_array(0 to 1)(2 downto 0);
    signal tx_slip : unsigned_array(0 to 1)(2 downto 0);

begin
    -- Decode registers into system and GDDR6 registers
    decode_registers : entity work.decode_registers port map (
        clk_i => clk_i,
        riu_clk_ok_i => ck_clk_ok,
        riu_clk_i => riu_clk,

        -- Internal registers from AXI-lite
        write_strobe_i => regs_write_strobe_i,
        write_address_i => regs_write_address_i,
        write_data_i => regs_write_data_i,
        write_ack_o => regs_write_ack_o,
        read_strobe_i => regs_read_strobe_i,
        read_address_i => regs_read_address_i,
        read_data_o => regs_read_data_o,
        read_ack_o => regs_read_ack_o,

        -- System registers on clk domain
        sys_write_strobe_o => sys_write_strobe,
        sys_write_data_o => sys_write_data,
        sys_write_ack_i => sys_write_ack,
        sys_read_data_i => sys_read_data,
        sys_read_strobe_o => sys_read_strobe,
        sys_read_ack_i => sys_read_ack,

        -- GDDR6 PHY registers on riu_clk domain
        phy_write_strobe_o => phy_write_strobe,
        phy_write_data_o => phy_write_data,
        phy_write_ack_i => phy_write_ack,
        phy_read_data_i => phy_read_data,
        phy_read_strobe_o => phy_read_strobe,
        phy_read_ack_i => phy_read_ack
    );


    -- SYS registers
    system_registers : entity work.system_registers port map (
        clk_i => clk_i,

        write_strobe_i => sys_write_strobe,
        write_data_i => sys_write_data,
        write_ack_o => sys_write_ack,
        read_strobe_i => sys_read_strobe,
        read_data_o => sys_read_data,
        read_ack_o => sys_read_ack,

        lmk_command_select_o => lmk_command_select,
        lmk_status_i => lmk_status,
        lmk_reset_o => lmk_reset,
        lmk_sync_o => lmk_sync,

        lmk_write_strobe_o => lmk_write_strobe,
        lmk_write_ack_i => lmk_write_ack,
        lmk_read_write_n_o => lmk_read_write_n,
        lmk_address_o => lmk_address,
        lmk_data_o => lmk_data_out,
        lmk_write_select_o => lmk_write_select,
        lmk_read_strobe_o => lmk_read_strobe,
        lmk_read_ack_i => lmk_read_ack,
        lmk_data_i => lmk_data_in,

        ck_reset_o => ck_reset,
        ck_locked_i => ck_clk_ok
    );


    gddr6_registers : entity work.gddr6_registers port map (
        clk_i => riu_clk,

        write_strobe_i => phy_write_strobe,
        write_data_i => phy_write_data,
        write_ack_o => phy_write_ack,
        read_strobe_i => phy_read_strobe,
        read_data_o => phy_read_data,
        read_ack_o => phy_read_ack,

        ck_unlock_i => ck_unlock,
        fifo_ok_i => fifo_ok,

        sg_resets_o => sg_resets,
        enable_cabi_o => enable_cabi,
        enable_dbi_o => enable_dbi,
        rx_slip_o => rx_slip,
        tx_slip_o => tx_slip,
        dq_t_o => dq_t,

        ca_o => ca,
        ca3_o => ca3,
        cke_n_o => cke_n,

        dq_data_i => dq_data_in,
        dq_data_o => dq_data_out,
        edc_in_i => edc_in,
        edc_out_i => edc_out,

        riu_addr_o => riu_addr,
        riu_wr_data_o => riu_wr_data,
        riu_rd_data_i => riu_rd_data,
        riu_wr_en_o => riu_wr_en,
        riu_strobe_o => riu_strobe,
        riu_ack_i => riu_ack,
        riu_error_i => riu_error,
        riu_vtc_handshake_o => riu_vtc_handshake
    );


    -- -------------------------------------------------------------------------
    -- Device interfaces


    lmk04616 : entity work.lmk04616 port map (
        clk_i => clk_i,

        command_select_i => lmk_command_select,
        select_valid_o => open,
        status_o => lmk_status,
        reset_i => lmk_reset,
        sync_i => lmk_sync,

        write_strobe_i => lmk_write_strobe,
        write_ack_o => lmk_write_ack,
        read_write_n_i => lmk_read_write_n,
        address_i => lmk_address,
        data_i => lmk_data_out,
        write_select_i => lmk_write_select,

        read_strobe_i => lmk_read_strobe,
        read_ack_o => lmk_read_ack,
        data_o => lmk_data_in,

        pad_LMK_CTL_SEL_o => pad_LMK_CTL_SEL_o,
        pad_LMK_SCL_o => pad_LMK_SCL_o,
        pad_LMK_SCS_L_o => pad_LMK_SCS_L_o,
        pad_LMK_SDIO_io => pad_LMK_SDIO_io,
        pad_LMK_RESET_L_o => pad_LMK_RESET_L_o,
        pad_LMK_SYNC_io => pad_LMK_SYNC_io,
        pad_LMK_STATUS_io => pad_LMK_STATUS_io
    );


    phy : entity work.gddr6_phy generic map (
        CK_FREQUENCY => CK_FREQUENCY
    ) port map (
        ck_clk_o => ck_clk,
        riu_clk_o => riu_clk,
        ck_reset_i => ck_reset,
        ck_ok_o => raw_ck_clk_ok,
        ck_unlock_o => ck_unlock,
        fifo_ok_o => fifo_ok,

        sg_resets_i => sg_resets,

        ca_i => ca,
        ca3_i => ca3,
        cke_n_i => cke_n,
        enable_cabi_i => enable_cabi,

        data_i => dq_data_out,
        data_o => dq_data_in,
        dq_t_i => dq_t,
        enable_dbi_i => enable_dbi,
        edc_in_o => edc_in,
        edc_out_o => edc_out,

        riu_addr_i => riu_addr,
        riu_wr_data_i => riu_wr_data,
        riu_rd_data_o => riu_rd_data,
        riu_wr_en_i => riu_wr_en,
        riu_strobe_i => riu_strobe,
        riu_ack_o => riu_ack,
        riu_error_o => riu_error,
        riu_vtc_handshake_i => riu_vtc_handshake,
        rx_slip_i => rx_slip,
        tx_slip_i => tx_slip,

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

    sync_ck_ok : entity work.sync_bit port map (
        clk_i => clk_i,
        bit_i => raw_ck_clk_ok,
        bit_o => ck_clk_ok
    );
end;
