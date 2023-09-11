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


    -- -------------------------------------------------------------------------
    -- LMK config and status

    signal lmk_command_select : std_ulogic;
    signal lmk_status : std_ulogic_vector(1 downto 0);
    signal lmk_reset : std_ulogic;
    signal lmk_sync : std_ulogic;


    -- -------------------------------------------------------------------------
    -- GDDR6 setup

    signal ck_clk : std_ulogic;
    signal riu_clk : std_ulogic;
    signal ck_clk_ok : std_ulogic;
    signal reg_clk : std_ulogic;

    signal phy_ca : vector_array(0 to 1)(9 downto 0);
    signal phy_ca3 : std_ulogic_vector(0 to 3);
    signal phy_cke_n : std_ulogic;
    signal phy_dq_t : std_ulogic;
    signal phy_data_in : std_ulogic_vector(511 downto 0);
    signal phy_data_out : std_ulogic_vector(511 downto 0);
    signal phy_edc_in : vector_array(7 downto 0)(7 downto 0);
    signal phy_edc_out : vector_array(7 downto 0)(7 downto 0);

    signal riu_addr : unsigned(9 downto 0);
    signal riu_wr_data : std_ulogic_vector(15 downto 0);
    signal riu_rd_data : std_ulogic_vector(15 downto 0);
    signal riu_wr_en : std_ulogic;
    signal riu_strobe : std_ulogic;
    signal riu_ack : std_ulogic;
    signal riu_error : std_ulogic;
    signal riu_vtc_handshake : std_ulogic;

    signal ck_reset : std_ulogic;
    signal ck_unlock : std_ulogic;
    signal fifo_ok : std_ulogic;
    signal sg_resets_n : std_ulogic_vector(0 to 1);
    signal enable_cabi : std_ulogic;
    signal enable_dbi : std_ulogic;
    signal rx_slip : unsigned_array(0 to 1)(2 downto 0);
    signal tx_slip : unsigned_array(0 to 1)(2 downto 0);

begin
    register_mux : entity work.register_mux port map (
        clk_i => clk_i,

        write_strobe_i => regs_write_strobe_i,
        write_address_i => regs_write_address_i,
        write_data_i => regs_write_data_i,
        write_ack_o => regs_write_ack_o,
        read_strobe_i => regs_read_strobe_i,
        read_address_i => regs_read_address_i,
        read_data_o => regs_read_data_o,
        read_ack_o => regs_read_ack_o,

        write_strobe_o => sys_write_strobe,
        write_data_o => sys_write_data,
        write_ack_i => sys_write_ack,
        read_data_i => sys_read_data,
        read_strobe_o => sys_read_strobe,
        read_ack_i => sys_read_ack
    );


    -- SYS registers
    system_registers : entity work.system_registers port map (
        clk_i => clk_i,

        write_strobe_i => sys_write_strobe(SYS_CONTROL_REGS),
        write_data_i => sys_write_data(SYS_CONTROL_REGS),
        write_ack_o => sys_write_ack(SYS_CONTROL_REGS),
        read_strobe_i => sys_read_strobe(SYS_CONTROL_REGS),
        read_data_o => sys_read_data(SYS_CONTROL_REGS),
        read_ack_o => sys_read_ack(SYS_CONTROL_REGS),

        lmk_command_select_o => lmk_command_select,
        lmk_status_i => lmk_status,
        lmk_reset_o => lmk_reset,
        lmk_sync_o => lmk_sync
    );


    lmk04616 : entity work.lmk04616 port map (
        clk_i => clk_i,

        command_select_i => lmk_command_select,
        select_valid_o => open,
        status_o => lmk_status,
        reset_i => lmk_reset,
        sync_i => lmk_sync,

        write_strobe_i => sys_write_strobe(SYS_LMK04616_REG),
        write_data_i => sys_write_data(SYS_LMK04616_REG),
        write_ack_o => sys_write_ack(SYS_LMK04616_REG),
        read_strobe_i => sys_read_strobe(SYS_LMK04616_REG),
        read_data_o => sys_read_data(SYS_LMK04616_REG),
        read_ack_o => sys_read_ack(SYS_LMK04616_REG),

        pad_LMK_CTL_SEL_o => pad_LMK_CTL_SEL_o,
        pad_LMK_SCL_o => pad_LMK_SCL_o,
        pad_LMK_SCS_L_o => pad_LMK_SCS_L_o,
        pad_LMK_SDIO_io => pad_LMK_SDIO_io,
        pad_LMK_RESET_L_o => pad_LMK_RESET_L_o,
        pad_LMK_SYNC_io => pad_LMK_SYNC_io,
        pad_LMK_STATUS_io => pad_LMK_STATUS_io
    );


    setup : entity work.gddr6_setup port map (
        ck_clk_i => ck_clk,
        riu_clk_i => riu_clk,
        ck_clk_ok_i => ck_clk_ok,
        reg_clk_i => clk_i,

        write_strobe_i => sys_write_strobe(SYS_GDDR6_REGS),
        write_data_i => sys_write_data(SYS_GDDR6_REGS),
        write_ack_o => sys_write_ack(SYS_GDDR6_REGS),
        read_strobe_i => sys_read_strobe(SYS_GDDR6_REGS),
        read_data_o => sys_read_data(SYS_GDDR6_REGS),
        read_ack_o => sys_read_ack(SYS_GDDR6_REGS),

        phy_ca_o => phy_ca,
        phy_ca3_o => phy_ca3,
        phy_cke_n_o => phy_cke_n,
        phy_dq_t_o => phy_dq_t,
        phy_data_o => phy_data_out,
        phy_data_i => phy_data_in,
        phy_edc_in_i => phy_edc_in,
        phy_edc_out_i => phy_edc_out,

        riu_addr_o => riu_addr,
        riu_wr_data_o => riu_wr_data,
        riu_rd_data_i => riu_rd_data,
        riu_wr_en_o => riu_wr_en,
        riu_strobe_o => riu_strobe,
        riu_ack_i => riu_ack,
        riu_error_i => riu_error,
        riu_vtc_handshake_o => riu_vtc_handshake,

        ck_reset_o => ck_reset,
        ck_unlock_i => ck_unlock,
        fifo_ok_i => fifo_ok,
        sg_resets_n_o => sg_resets_n,

        enable_cabi_o => enable_cabi,
        enable_dbi_o => enable_dbi,
        rx_slip_o => rx_slip,
        tx_slip_o => tx_slip
    );


    phy : entity work.gddr6_phy generic map (
        CK_FREQUENCY => CK_FREQUENCY
    ) port map (
        ck_clk_o => ck_clk,
        riu_clk_o => riu_clk,
        ck_reset_i => ck_reset,
        ck_clk_ok_o => ck_clk_ok,
        ck_unlock_o => ck_unlock,
        fifo_ok_o => fifo_ok,

        sg_resets_n_i => sg_resets_n,

        ca_i => phy_ca,
        ca3_i => phy_ca3,
        cke_n_i => phy_cke_n,
        enable_cabi_i => enable_cabi,

        data_i => phy_data_out,
        data_o => phy_data_in,
        dq_t_i => phy_dq_t,
        enable_dbi_i => enable_dbi,
        edc_in_o => phy_edc_in,
        edc_out_o => phy_edc_out,

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
end;
