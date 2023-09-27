-- Configuration and monitoring

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.gddr6_register_defines.all;

entity gddr6_setup_control is
    port (
        ck_clk_i : in std_ulogic;       -- CK clock
        ck_clk_ok_i : in std_ulogic;    -- CK and RIU clocks ok
        reg_clk_i : in std_ulogic;      -- Register clock

        -- Register interface for data access
        write_strobe_i : in std_ulogic_vector(GDDR6_CONTROL_REGS);
        write_data_i : in reg_data_array_t(GDDR6_CONTROL_REGS);
        write_ack_o : out std_ulogic_vector(GDDR6_CONTROL_REGS);
        read_strobe_i : in std_ulogic_vector(GDDR6_CONTROL_REGS);
        read_data_o : out reg_data_array_t(GDDR6_CONTROL_REGS);
        read_ack_o : out std_ulogic_vector(GDDR6_CONTROL_REGS);

        -- Controls to PHY
        ck_reset_o : out std_ulogic;
        ck_unlock_i : in std_ulogic;
        reset_fifo_o : out std_ulogic_vector(0 to 1);
        fifo_ok_i : in std_ulogic_vector(0 to 1);
        sg_resets_n_o : out std_ulogic_vector(0 to 1);
        enable_cabi_o : out std_ulogic;
        enable_dbi_o : out std_ulogic;

        -- Individual delay resets
        delay_reset_ca_o : out std_ulogic;
        delay_reset_dq_rx_o : out std_ulogic;
        delay_reset_dq_tx_o : out std_ulogic;

        -- Controller enable
        enable_controller_o : out std_ulogic
    );
end;

architecture arch of gddr6_setup_control is
    -- Plumbing for CK status readout
    signal reg_read_status : reg_data_t;
    signal ck_read_status : reg_data_t;
    signal ck_status_read_strobe : std_ulogic;
    signal ck_status_read_ack : std_ulogic;
    signal ck_status_read_data : reg_data_t;

    -- Config, status, event bits for both clock domains
    signal reg_config_bits : reg_data_t;
    signal ck_config_bits : reg_data_t;
    signal reg_status_bits : reg_data_t;
    signal ck_status_bits : reg_data_t;
    signal reg_event_bits : reg_data_t;
    signal ck_event_bits : reg_data_t;

begin
    -- CONFIG
    -- The config register is overlaid so that writes are directed to both
    -- domains, but only acknowleged on the CK domain.  For reading we can
    -- just read back from the REG domain.

    reg_config : entity work.register_file_rw port map (
        clk_i => reg_clk_i,

        write_strobe_i(0) => write_strobe_i(GDDR6_CONFIG_REG),
        write_data_i(0) => write_data_i(GDDR6_CONFIG_REG),
        write_ack_o(0) => open,
        read_strobe_i(0) => read_strobe_i(GDDR6_CONFIG_REG),
        read_data_o(0) => read_data_o(GDDR6_CONFIG_REG),
        read_ack_o(0) => read_ack_o(GDDR6_CONFIG_REG),

        register_data_o(0) => reg_config_bits
    );

    ck_config : entity work.register_file_cc port map (
        clk_reg_i => reg_clk_i,
        clk_data_i => ck_clk_i,
        clk_data_ok_i => ck_clk_ok_i,

        write_strobe_i(0) => write_strobe_i(GDDR6_CONFIG_REG),
        write_data_i(0) => write_data_i(GDDR6_CONFIG_REG),
        write_ack_o(0) => write_ack_o(GDDR6_CONFIG_REG),

        data_strobe_o(0) => open,
        register_data_o(0) => ck_config_bits
    );


    -- STATUS
    -- The status register is read only, but we need to merge bits for the
    -- returned result.  Again, use the CK domain to return the ack.

    reg_status : entity work.register_status port map (
        clk_i => reg_clk_i,

        read_strobe_i => read_strobe_i(GDDR6_STATUS_REG),
        read_data_o => reg_read_status,
        read_ack_o => open,

        status_bits_i => reg_status_bits,
        event_bits_i => reg_event_bits
    );

    reg_to_ck : entity work.cross_clocks_read port map (
        clk_in_i => reg_clk_i,
        clk_out_i => ck_clk_i,
        clk_out_ok_i => ck_clk_ok_i,

        strobe_i => read_strobe_i(GDDR6_STATUS_REG),
        data_o => ck_read_status,
        ack_o => read_ack_o(GDDR6_STATUS_REG),

        strobe_o => ck_status_read_strobe,
        data_i => ck_status_read_data,
        ack_i => ck_status_read_ack
    );

    ck_status : entity work.register_status port map (
        clk_i => ck_clk_i,

        read_strobe_i => ck_status_read_strobe,
        read_data_o => ck_status_read_data,
        read_ack_o => ck_status_read_ack,

        status_bits_i => ck_status_bits,
        event_bits_i => ck_event_bits
    );

    read_data_o(GDDR6_STATUS_REG) <= reg_read_status or ck_read_status;
    write_ack_o(GDDR6_STATUS_REG) <= '1';


    -- -------------------------------------------------------------------------

    process (reg_clk_i) begin
        if rising_edge(reg_clk_i) then
            ck_reset_o <= not reg_config_bits(GDDR6_CONFIG_CK_RESET_N_BIT);

            reg_status_bits <= (
                GDDR6_STATUS_CK_OK_BIT => ck_clk_ok_i,
                others => '0');
            reg_event_bits <= (
                GDDR6_STATUS_CK_OK_EVENT_BIT => ck_clk_ok_i,
                others => '0');
        end if;
    end process;

    process (ck_clk_i) begin
        if rising_edge(ck_clk_i) then
            sg_resets_n_o <= ck_config_bits(GDDR6_CONFIG_SG_RESET_N_BITS);
            enable_cabi_o <= ck_config_bits(GDDR6_CONFIG_ENABLE_CABI_BIT);
            enable_dbi_o <= ck_config_bits(GDDR6_CONFIG_ENABLE_DBI_BIT);
            reset_fifo_o <= ck_config_bits(GDDR6_CONFIG_RESET_FIFO_BITS);
            enable_controller_o <=
                ck_config_bits(GDDR6_CONFIG_ENABLE_CONTROL_BIT);
            delay_reset_ca_o <=
                ck_config_bits(GDDR6_CONFIG_RESET_CA_ODELAY_BIT);
            delay_reset_dq_tx_o <=
                ck_config_bits(GDDR6_CONFIG_RESET_DQ_ODELAY_BIT);
            delay_reset_dq_rx_o <=
                ck_config_bits(GDDR6_CONFIG_RESET_DQ_IDELAY_BIT);

            ck_status_bits <= (
                GDDR6_STATUS_FIFO_OK_BITS => fifo_ok_i,
                others => '0');
            ck_event_bits <= (
                GDDR6_STATUS_CK_UNLOCK_EVENT_BIT => ck_unlock_i,
                GDDR6_STATUS_FIFO_OK_EVENT_BITS => fifo_ok_i,
                others => '0');
        end if;
    end process;
end;
