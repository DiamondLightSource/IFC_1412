library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.register_defines.all;
use work.version.all;

use work.sim_support.all;

entity testbench is
end testbench;


architecture arch of testbench is
    constant CK_FREQUENCY : real := 300.0;

    constant CK_WIDTH : time := 1 us / CK_FREQUENCY;
    constant WCK_WIDTH : time := CK_WIDTH / 4;

    signal pad_LMK_CTL_SEL : std_ulogic;
    signal pad_LMK_SCL : std_ulogic;
    signal pad_LMK_SCS_L : std_ulogic;
    signal pad_LMK_SDIO : std_logic;
    signal pad_LMK_RESET_L : std_ulogic;
    signal pad_LMK_SYNC : std_logic;
    signal pad_LMK_STATUS : std_logic_vector(0 to 1);
    signal pad_SG12_CK_P : std_ulogic := '0';
    signal pad_SG12_CK_N : std_ulogic;
    signal pad_SG1_WCK_P : std_ulogic := '0';
    signal pad_SG1_WCK_N : std_ulogic;
    signal pad_SG2_WCK_P : std_ulogic;
    signal pad_SG2_WCK_N : std_ulogic;
    signal pad_SG1_RESET_N : std_ulogic;
    signal pad_SG2_RESET_N : std_ulogic;
    signal pad_SG12_CKE_N : std_ulogic;
    signal pad_SG12_CAL : std_ulogic_vector(2 downto 0);
    signal pad_SG1_CA3_A : std_ulogic;
    signal pad_SG1_CA3_B : std_ulogic;
    signal pad_SG2_CA3_A : std_ulogic;
    signal pad_SG2_CA3_B : std_ulogic;
    signal pad_SG12_CAU : std_ulogic_vector(9 downto 4);
    signal pad_SG12_CABI_N : std_ulogic;
    signal pad_SG1_DQ_A : std_logic_vector(15 downto 0);
    signal pad_SG1_DQ_B : std_logic_vector(15 downto 0);
    signal pad_SG2_DQ_A : std_logic_vector(15 downto 0);
    signal pad_SG2_DQ_B : std_logic_vector(15 downto 0);
    signal pad_SG1_DBI_N_A : std_logic_vector(1 downto 0);
    signal pad_SG1_DBI_N_B : std_logic_vector(1 downto 0);
    signal pad_SG2_DBI_N_A : std_logic_vector(1 downto 0);
    signal pad_SG2_DBI_N_B : std_logic_vector(1 downto 0);
    signal pad_SG1_EDC_A : std_logic_vector(1 downto 0);
    signal pad_SG1_EDC_B : std_logic_vector(1 downto 0);
    signal pad_SG2_EDC_A : std_logic_vector(1 downto 0);
    signal pad_SG2_EDC_B : std_logic_vector(1 downto 0);

    signal clk : std_ulogic := '0';

    signal regs_write_strobe : std_ulogic;
    signal regs_write_address : unsigned(13 downto 0);
    signal regs_write_data : std_ulogic_vector(31 downto 0);
    signal regs_write_ack : std_ulogic;
    signal regs_read_strobe : std_ulogic;
    signal regs_read_address : unsigned(13 downto 0);
    signal regs_read_data : std_ulogic_vector(31 downto 0);
    signal regs_read_ack : std_ulogic;

begin
    clk <= not clk after 2 ns;

    test_gddr6_phy : entity work.test_gddr6_phy generic map (
        CK_FREQUENCY => CK_FREQUENCY
    ) port map (
        clk_i => clk,

        regs_write_strobe_i => regs_write_strobe,
        regs_write_address_i => regs_write_address,
        regs_write_data_i => regs_write_data,
        regs_write_ack_o => regs_write_ack,
        regs_read_strobe_i => regs_read_strobe,
        regs_read_address_i => regs_read_address,
        regs_read_data_o => regs_read_data,
        regs_read_ack_o => regs_read_ack,

        pad_LMK_CTL_SEL_o => pad_LMK_CTL_SEL,
        pad_LMK_SCL_o => pad_LMK_SCL,
        pad_LMK_SCS_L_o => pad_LMK_SCS_L,
        pad_LMK_SDIO_io => pad_LMK_SDIO,
        pad_LMK_RESET_L_o => pad_LMK_RESET_L,
        pad_LMK_SYNC_io => pad_LMK_SYNC,
        pad_LMK_STATUS_io => pad_LMK_STATUS,

        pad_SG12_CK_P_i => pad_SG12_CK_P,
        pad_SG12_CK_N_i => pad_SG12_CK_N,
        pad_SG1_WCK_P_i => pad_SG1_WCK_P,
        pad_SG1_WCK_N_i => pad_SG1_WCK_N,
        pad_SG2_WCK_P_i => pad_SG2_WCK_P,
        pad_SG2_WCK_N_i => pad_SG2_WCK_N,
        pad_SG1_RESET_N_o => pad_SG1_RESET_N,
        pad_SG2_RESET_N_o => pad_SG2_RESET_N,
        pad_SG12_CKE_N_o => pad_SG12_CKE_N,
        pad_SG12_CAL_o => pad_SG12_CAL,
        pad_SG1_CA3_A_o => pad_SG1_CA3_A,
        pad_SG1_CA3_B_o => pad_SG1_CA3_B,
        pad_SG2_CA3_A_o => pad_SG2_CA3_A,
        pad_SG2_CA3_B_o => pad_SG2_CA3_B,
        pad_SG12_CAU_o => pad_SG12_CAU,
        pad_SG12_CABI_N_o => pad_SG12_CABI_N,
        pad_SG1_DQ_A_io => pad_SG1_DQ_A,
        pad_SG1_DQ_B_io => pad_SG1_DQ_B,
        pad_SG2_DQ_A_io => pad_SG2_DQ_A,
        pad_SG2_DQ_B_io => pad_SG2_DQ_B,
        pad_SG1_DBI_N_A_io => pad_SG1_DBI_N_A,
        pad_SG1_DBI_N_B_io => pad_SG1_DBI_N_B,
        pad_SG2_DBI_N_A_io => pad_SG2_DBI_N_A,
        pad_SG2_DBI_N_B_io => pad_SG2_DBI_N_B,
        pad_SG1_EDC_A_io => pad_SG1_EDC_A,
        pad_SG1_EDC_B_io => pad_SG1_EDC_B,
        pad_SG2_EDC_A_io => pad_SG2_EDC_A,
        pad_SG2_EDC_B_io => pad_SG2_EDC_B
    );

    pad_LMK_SDIO <= 'H';
    pad_LMK_STATUS <= "LL";

    -- Run CK at 300 MHz (we should be so lucky on real hardware)
    pad_SG12_CK_P <= not pad_SG12_CK_P after CK_WIDTH / 2;
    pad_SG12_CK_N <= not pad_SG12_CK_P;
    -- Run WCK at 4 times this frequency
    pad_SG1_WCK_P <= not pad_SG1_WCK_P after WCK_WIDTH / 2;
    pad_SG1_WCK_N <= not pad_SG1_WCK_P;
    pad_SG2_WCK_P <= pad_SG1_WCK_P;
    pad_SG2_WCK_N <= pad_SG1_WCK_N;

    process
        procedure clk_wait(count : natural := 1) is
        begin
            clk_wait(clk, count);
        end;

        procedure write_reg(reg : natural; value : reg_data_t) is
        begin
            write_reg(
                clk, regs_write_data, regs_write_address, regs_write_strobe,
                regs_write_ack, reg, value);
        end;

        procedure read_reg(reg : natural) is
        begin
            read_reg(
                clk, regs_read_data, regs_read_address, regs_read_strobe,
                regs_read_ack, reg);
        end;

        procedure read_reg_result(reg : natural; result : out reg_data_t) is
        begin
            read_reg_result(
                clk, regs_read_data, regs_read_address, regs_read_strobe,
                regs_read_ack, reg, result);
        end;

        -- Registers are split into two groups
        constant SYS_BASE : natural := 0;
        constant PHY_BASE : natural := 32;

        variable read_result : reg_data_t;

    begin
        regs_write_strobe <= '0';
        regs_read_strobe <= '0';

        clk_wait(5);
        read_reg_result(SYS_BASE + SYS_GIT_VERSION_REG, read_result);
        assert
            to_integer(unsigned(read_result(SYS_GIT_VERSION_SHA_BITS)))
                = GIT_VERSION and
            to_integer(read_result(SYS_GIT_VERSION_DIRTY_BIT)) = GIT_DIRTY
            report "Unexpected GIT VERSION " & to_hstring(read_result)
            severity failure;
        -- This will fail to begin with because CK is not running
        read_reg_result(PHY_BASE + PHY_IDENT_REG, read_result);
        assert read_result = (reg_data_t'RANGE => 'U')
            report "Unexpected IDENT " & to_hstring(read_result)
            severity failure;

        -- Read events and stats
        read_reg(SYS_BASE + SYS_EVENTS_REG);
        read_reg(SYS_BASE + SYS_STATUS_REG);

        -- Now take CK out of reset
        write_reg(SYS_BASE + SYS_CONFIG_REG, (
            SYS_CONFIG_CK_RESET_N_BIT => '1',
            others => '0'));

        -- Try an LMK transaction
        write_reg(SYS_BASE + SYS_LMK04616_REG, (
            SYS_LMK04616_ADDRESS_BITS => 15X"0123",
            SYS_LMK04616_R_WN_BIT => '1',
            SYS_LMK04616_SELECT_BIT => '1',
            others => '0'));
        read_reg(SYS_BASE + SYS_LMK04616_REG);

        -- Wait for locked status
        loop
            read_reg_result(SYS_BASE + SYS_STATUS_REG, read_result);
            exit when read_result(SYS_STATUS_CK_LOCKED_BIT);
        end loop;

        -- Now try reading PHY IDENT again
        read_reg_result(PHY_BASE + PHY_IDENT_REG, read_result);
        assert to_integer(unsigned(read_result)) = PHY_MAGIC_NUMBER
            report "Unexpected IDENT " & to_hstring(read_result)
            severity failure;

        wait;
    end process;
end;
