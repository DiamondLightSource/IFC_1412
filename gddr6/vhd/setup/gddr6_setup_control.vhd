-- Configuration and monitoring

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.gddr6_register_defines.all;
use work.gddr6_defs.all;

entity gddr6_setup_control is
    port (
        ck_clk_i : in std_ulogic;       -- CK clock
        ck_clk_ok_i : in std_ulogic;    -- CK and RIU clocks ok
        reg_clk_i : in std_ulogic;      -- Register clock
        ck_reset_o : out std_ulogic := '0';

        -- Register interface for data access
        write_strobe_i : in std_ulogic_vector(GDDR6_CONTROL_REGS);
        write_data_i : in reg_data_array_t(GDDR6_CONTROL_REGS);
        write_ack_o : out std_ulogic_vector(GDDR6_CONTROL_REGS);
        read_strobe_i : in std_ulogic_vector(GDDR6_CONTROL_REGS);
        read_data_o : out reg_data_array_t(GDDR6_CONTROL_REGS);
        read_ack_o : out std_ulogic_vector(GDDR6_CONTROL_REGS);

        -- Controls to PHY
        phy_setup_o : out phy_setup_t;
        phy_status_i : in phy_status_t;

        -- Controller enable
        enable_controller_o : out std_ulogic := '0'
    );
end;

architecture arch of gddr6_setup_control is
    -- Plumbing for CK status readout
    signal reg_read_status : reg_data_t;
    signal reg_read_status_ack : std_ulogic;
    signal ck_read_status : reg_data_t;
    signal ck_read_status_ack : std_ulogic;
    signal reg_to_ck_status_read_strobe : std_ulogic;
    signal reg_to_ck_status_read_ack : std_ulogic;
    signal reg_to_ck_status_read_data : reg_data_t;
    signal read_status_strobe : std_ulogic;
    signal read_status_ack : std_ulogic;
    -- Tracking ACK status to cope with unreliable CK response
    signal need_reg_ack : std_ulogic := '0';
    signal need_ck_ack : std_ulogic := '0';

    -- Config, status, event bits for both clock domains
    signal reg_config_bits : reg_data_t;
    signal ck_config_bits : reg_data_t := (others => '0');
    signal reg_status_bits : reg_data_t := (others => '0');
    signal ck_status_bits : reg_data_t := (others => '0');
    signal reg_event_bits : reg_data_t := (others => '0');
    signal ck_event_bits : reg_data_t := (others => '0');

    -- Because this signal is being used as an asynchronous reset we need to
    -- mark it accordingly.
    attribute KEEP : string;
    attribute FALSE_PATH_FROM : string;
    attribute KEEP of ck_reset_o : signal is "TRUE";
    attribute FALSE_PATH_FROM of ck_reset_o : signal is "TRUE";

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

        read_strobe_i => read_status_strobe,
        read_data_o => reg_read_status,
        read_ack_o => reg_read_status_ack,

        status_bits_i => reg_status_bits,
        event_bits_i => reg_event_bits
    );

    reg_to_ck : entity work.cross_clocks_read port map (
        clk_in_i => reg_clk_i,
        clk_out_i => ck_clk_i,
        clk_out_ok_i => ck_clk_ok_i,

        strobe_i => read_status_strobe,
        data_o => ck_read_status,
        ack_o => ck_read_status_ack,

        strobe_o => reg_to_ck_status_read_strobe,
        data_i => reg_to_ck_status_read_data,
        ack_i => reg_to_ck_status_read_ack
    );

    ck_status : entity work.register_status port map (
        clk_i => ck_clk_i,

        read_strobe_i => reg_to_ck_status_read_strobe,
        read_data_o => reg_to_ck_status_read_data,
        read_ack_o => reg_to_ck_status_read_ack,

        status_bits_i => ck_status_bits,
        event_bits_i => ck_event_bits
    );

    read_status_strobe <= read_strobe_i(GDDR6_STATUS_REG);
    read_ack_o(GDDR6_STATUS_REG) <= read_status_ack;
    read_data_o(GDDR6_STATUS_REG) <= reg_read_status or ck_read_status;
    write_ack_o(GDDR6_STATUS_REG) <= '1';


    -- -------------------------------------------------------------------------

    process (reg_clk_i)
        variable next_need_reg_ack : std_ulogic;
        variable next_need_ck_ack : std_ulogic;
    begin
        if rising_edge(reg_clk_i) then
            ck_reset_o <= not reg_config_bits(GDDR6_CONFIG_CK_RESET_N_BIT);

            reg_status_bits <= (
                GDDR6_STATUS_CK_OK_BIT => ck_clk_ok_i,
                others => '0');
            reg_event_bits <= (
                GDDR6_STATUS_CK_OK_EVENT_BIT => not ck_clk_ok_i,
                others => '0');

            -- Computing the status ack is annoyingly gnarly.  We want to ensure
            -- that we have seen the ack from both domains (reg and ck) and we
            -- need to take care not to miss any ack, in particular the CK ack
            -- can be missed if ck_clk_ok_i changes state.
            if read_status_strobe then
                next_need_reg_ack := not reg_read_status_ack;
                next_need_ck_ack  := not ck_read_status_ack;
            else
                next_need_reg_ack := not reg_read_status_ack and need_reg_ack;
                next_need_ck_ack  := not ck_read_status_ack  and need_ck_ack;
            end if;
            need_reg_ack <= next_need_reg_ack;
            need_ck_ack  <= next_need_ck_ack;
            -- Can finally acknowledge status request when both acks are seen
            read_status_ack <=
                (need_reg_ack or need_ck_ack) and
                not next_need_reg_ack and not next_need_ck_ack;
        end if;
    end process;

    process (ck_clk_i) begin
        if rising_edge(ck_clk_i) then
            phy_setup_o <= (
                sg_resets_n =>
                    reverse(ck_config_bits(GDDR6_CONFIG_SG_RESET_N_BITS)),
                edc_tri => ck_config_bits(GDDR6_CONFIG_EDC_T_BIT),
                enable_cabi =>
                    ck_config_bits(GDDR6_CONFIG_ENABLE_CABI_BIT),
                enable_dbi =>
                    ck_config_bits(GDDR6_CONFIG_ENABLE_DBI_BIT),
                capture_dbi =>
                    ck_config_bits(GDDR6_CONFIG_CAPTURE_DBI_BIT),
                edc_delay =>
                    unsigned(ck_config_bits(GDDR6_CONFIG_EDC_DELAY_BITS)),
                reset_fifo =>
                    reverse(ck_config_bits(GDDR6_CONFIG_RESET_FIFO_BITS)),

                -- Special fudge for prototype board, must be removed.  Used to
                -- work around sticky CA6 bit.
                fudge_sticky_ca6 =>
                    ck_config_bits(GDDR6_CONFIG_FUDGE_STICKY_CA6_BIT),
                disable_vtc =>
                    ck_config_bits(GDDR6_CONFIG_DISABLE_VTC_BIT)
            );

            enable_controller_o <=
                ck_config_bits(GDDR6_CONFIG_ENABLE_CONTROL_BIT);

            ck_status_bits <= (
                GDDR6_STATUS_FIFO_OK_BITS => reverse(phy_status_i.fifo_ok),
                others => '0');
            ck_event_bits <= (
                GDDR6_STATUS_CK_UNLOCK_EVENT_BIT => phy_status_i.ck_unlock,
                GDDR6_STATUS_FIFO_OK_EVENT_BITS => not phy_status_i.fifo_ok,
                others => '0');
        end if;
    end process;
end;
