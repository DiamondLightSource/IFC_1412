-- Top level test for gddr6 phy test

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.register_defines.all;

entity test_gddr6_phy is
    generic (
        CK_FREQUENCY : real := 250.0;
        ENABLE_DELAY_READBACK : boolean := false
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

    -- LMK config and status
    signal lmk_command_select : std_ulogic;
    signal lmk_status : std_ulogic_vector(1 downto 0);
    signal lmk_reset : std_ulogic;
    signal lmk_sync : std_ulogic;

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


    setup_phy : entity work.gddr6_setup_phy generic map (
        CK_FREQUENCY => CK_FREQUENCY,
        ENABLE_DELAY_READBACK => ENABLE_DELAY_READBACK
    ) port map (
        reg_clk_i => clk_i,

        write_strobe_i => sys_write_strobe(SYS_GDDR6_REGS),
        write_data_i => sys_write_data(SYS_GDDR6_REGS),
        write_ack_o => sys_write_ack(SYS_GDDR6_REGS),
        read_strobe_i => sys_read_strobe(SYS_GDDR6_REGS),
        read_data_o => sys_read_data(SYS_GDDR6_REGS),
        read_ack_o => sys_read_ack(SYS_GDDR6_REGS),

        -- Unused operational interface
        ck_clk_o => open,
        ctrl_ca_i => (others => (others => '0')),
        ctrl_ca3_i => (others => '0'),
        ctrl_cke_n_i => "00",
        ctrl_data_i => (others => '0'),
        ctrl_data_o => open,
        ctrl_output_enable_i => '0',
        ctrl_edc_in_o => open,
        ctrl_edc_out_o => open,

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
