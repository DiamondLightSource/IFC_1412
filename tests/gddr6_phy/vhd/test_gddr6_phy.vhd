-- Top level test for gddr6 phy test

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.register_defines.all;
use work.version.all;

use work.gddr6_defs.all;

entity test_gddr6_phy is
    generic (
        CK_FREQUENCY : real := 250.0
    );
    port (
        clk_i : in std_ulogic;

        write_strobe_i : in std_ulogic;
        write_address_i : in unsigned(13 downto 0);
        write_data_i : in std_ulogic_vector(31 downto 0);
        write_ack_o : out std_ulogic;
        read_strobe_i : in std_ulogic;
        read_address_i : in unsigned(13 downto 0);
        read_data_o : out std_ulogic_vector(31 downto 0);
        read_ack_o : out std_ulogic;

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
    signal write_strobe : std_ulogic_vector(SYS_REGS_RANGE);
    signal write_data : reg_data_array_t(SYS_REGS_RANGE);
    signal write_ack : std_ulogic_vector(SYS_REGS_RANGE);
    signal read_strobe : std_ulogic_vector(SYS_REGS_RANGE);
    signal read_data : reg_data_array_t(SYS_REGS_RANGE);
    signal read_ack : std_ulogic_vector(SYS_REGS_RANGE);

    signal capture_trigger : std_ulogic;
    signal axi_request : axi_request_t;
    signal axi_response : axi_response_t;
    signal axi_stats : axi_stats_t;

begin
    register_mux : entity work.register_mux port map (
        clk_i => clk_i,

        write_strobe_i => write_strobe_i,
        write_address_i => write_address_i,
        write_data_i => write_data_i,
        write_ack_o => write_ack_o,
        read_strobe_i => read_strobe_i,
        read_address_i => read_address_i,
        read_data_o => read_data_o,
        read_ack_o => read_ack_o,

        write_strobe_o => write_strobe,
        write_data_o => write_data,
        write_ack_i => write_ack,
        read_data_i => read_data,
        read_strobe_o => read_strobe,
        read_ack_i => read_ack
    );


    -- SYS registers
    read_data(SYS_GIT_VERSION_REG) <= (
        SYS_GIT_VERSION_SHA_BITS => to_std_ulogic_vector_u(GIT_VERSION, 28),
        SYS_GIT_VERSION_DIRTY_BIT => to_std_ulogic(GIT_DIRTY),
        others => '0'
    );
    read_ack(SYS_GIT_VERSION_REG) <= '1';
    write_ack(SYS_GIT_VERSION_REG) <= '1';


    lmk04616 : entity work.lmk04616 port map (
        clk_i => clk_i,

        write_strobe_i => write_strobe(SYS_LMK04616_REG),
        write_data_i => write_data(SYS_LMK04616_REG),
        write_ack_o => write_ack(SYS_LMK04616_REG),
        read_strobe_i => read_strobe(SYS_LMK04616_REG),
        read_data_o => read_data(SYS_LMK04616_REG),
        read_ack_o => read_ack(SYS_LMK04616_REG),

        pad_LMK_CTL_SEL_o => pad_LMK_CTL_SEL_o,
        pad_LMK_SCL_o => pad_LMK_SCL_o,
        pad_LMK_SCS_L_o => pad_LMK_SCS_L_o,
        pad_LMK_SDIO_io => pad_LMK_SDIO_io,
        pad_LMK_RESET_L_o => pad_LMK_RESET_L_o,
        pad_LMK_SYNC_io => pad_LMK_SYNC_io,
        pad_LMK_STATUS_io => pad_LMK_STATUS_io
    );


    axi : entity work.axi port map (
        clk_i => clk_i,

        write_strobe_i => write_strobe(SYS_AXI_REGS),
        write_data_i => write_data(SYS_AXI_REGS),
        write_ack_o => write_ack(SYS_AXI_REGS),
        read_strobe_i => read_strobe(SYS_AXI_REGS),
        read_data_o => read_data(SYS_AXI_REGS),
        read_ack_o => read_ack(SYS_AXI_REGS),

        capture_trigger_o => capture_trigger,

        axi_request_o => axi_request,
        axi_response_i => axi_response,
        axi_stats_i => axi_stats
    );


    gddr6 : entity work.gddr6 generic map (
        CK_FREQUENCY => CK_FREQUENCY
    ) port map (
        setup_clk_i => clk_i,

        write_strobe_i => write_strobe(SYS_GDDR6_REGS),
        write_data_i => write_data(SYS_GDDR6_REGS),
        write_ack_o => write_ack(SYS_GDDR6_REGS),
        read_strobe_i => read_strobe(SYS_GDDR6_REGS),
        read_data_o => read_data(SYS_GDDR6_REGS),
        read_ack_o => read_ack(SYS_GDDR6_REGS),

        setup_trigger_i => capture_trigger,

        axi_clk_i => clk_i,

        axi_request_i => axi_request,
        axi_response_o => axi_response,
        axi_stats_o => axi_stats,

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
