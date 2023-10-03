-- Top level control for gddr6 setup

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.gddr6_register_defines.all;

entity gddr6_setup is
    generic (
        -- Delay readback is quite expensive in terms of fabric, so is optional
        ENABLE_DELAY_READBACK : boolean := false
    );
    port (
        reg_clk_i : in std_ulogic;      -- Register clock

        -- Register interface for data access on reg_clk_i
        write_strobe_i : in std_ulogic_vector(GDDR6_REGS_RANGE);
        write_data_i : in reg_data_array_t(GDDR6_REGS_RANGE);
        write_ack_o : out std_ulogic_vector(GDDR6_REGS_RANGE);
        read_strobe_i : in std_ulogic_vector(GDDR6_REGS_RANGE);
        read_data_o : out reg_data_array_t(GDDR6_REGS_RANGE);
        read_ack_o : out std_ulogic_vector(GDDR6_REGS_RANGE);

        -- CK clock, used for all other elements of the interface
        ck_clk_i : in std_ulogic;       -- CK clock
        ck_clk_ok_i : in std_ulogic;    -- Qualifies status of CK clock

        -- PHY interface on ck_clk_i, connected to gddr6_phy
        phy_ca_o : out vector_array(0 to 1)(9 downto 0);
        phy_ca3_o : out std_ulogic_vector(0 to 3);
        phy_cke_n_o : out std_ulogic;
        phy_output_enable_o : out std_ulogic;
        phy_data_o : out std_ulogic_vector(511 downto 0);
        phy_data_i : in std_ulogic_vector(511 downto 0);
        phy_edc_in_i : in vector_array(7 downto 0)(7 downto 0);
        phy_edc_out_i : in vector_array(7 downto 0)(7 downto 0);

        -- Delay control on delay_clk_i
        delay_address_o : out unsigned(7 downto 0);
        delay_o : out unsigned(7 downto 0);
        delay_up_down_n_o : out std_ulogic;
        delay_byteslip_o : out std_ulogic;
        delay_read_write_n_o : out std_ulogic;
        delay_i : in unsigned(8 downto 0);
        delay_strobe_o : out std_ulogic;
        delay_ack_i : in std_ulogic;
        -- Individual delay resets
        delay_reset_ca_o : out std_ulogic;
        delay_reset_dq_rx_o : out std_ulogic;
        delay_reset_dq_tx_o : out std_ulogic;

        -- Controls to PHY
        ck_reset_o : out std_ulogic;
        ck_unlock_i : in std_ulogic;
        reset_fifo_o : out std_ulogic_vector(0 to 1);
        fifo_ok_i : in std_ulogic_vector(0 to 1);
        sg_resets_n_o : out std_ulogic_vector(0 to 1);
        edc_t_o : out std_ulogic;
        enable_cabi_o : out std_ulogic;
        enable_dbi_o : out std_ulogic;

        -- Controller enable
        enable_controller_o : out std_ulogic
    );
end;

architecture arch of gddr6_setup is
    signal ck_clk_ok : std_ulogic;

begin
    sync_ck_ok : entity work.sync_bit port map (
        clk_i => reg_clk_i,
        bit_i => ck_clk_ok_i,
        bit_o => ck_clk_ok
    );


    control : entity work.gddr6_setup_control port map (
        reg_clk_i => reg_clk_i,
        ck_clk_i => ck_clk_i,
        ck_clk_ok_i => ck_clk_ok,

        write_strobe_i => write_strobe_i(GDDR6_CONTROL_REGS),
        write_data_i => write_data_i(GDDR6_CONTROL_REGS),
        write_ack_o => write_ack_o(GDDR6_CONTROL_REGS),
        read_strobe_i => read_strobe_i(GDDR6_CONTROL_REGS),
        read_data_o => read_data_o(GDDR6_CONTROL_REGS),
        read_ack_o => read_ack_o(GDDR6_CONTROL_REGS),

        ck_reset_o => ck_reset_o,
        ck_unlock_i => ck_unlock_i,
        reset_fifo_o => reset_fifo_o,
        fifo_ok_i => fifo_ok_i,
        sg_resets_n_o => sg_resets_n_o,
        edc_t_o => edc_t_o,
        enable_cabi_o => enable_cabi_o,
        enable_dbi_o => enable_dbi_o,

        delay_reset_ca_o => delay_reset_ca_o,
        delay_reset_dq_rx_o => delay_reset_dq_rx_o,
        delay_reset_dq_tx_o => delay_reset_dq_tx_o,

        enable_controller_o => enable_controller_o
    );


    delay : entity work.gddr6_setup_delay generic map (
        ENABLE_DELAY_READBACK => ENABLE_DELAY_READBACK
    ) port map (
        reg_clk_i => reg_clk_i,
        ck_clk_i => ck_clk_i,
        ck_clk_ok_i => ck_clk_ok,

        write_strobe_i => write_strobe_i(GDDR6_DELAY_REG),
        write_data_i => write_data_i(GDDR6_DELAY_REG),
        write_ack_o => write_ack_o(GDDR6_DELAY_REG),
        read_strobe_i => read_strobe_i(GDDR6_DELAY_REG),
        read_data_o => read_data_o(GDDR6_DELAY_REG),
        read_ack_o => read_ack_o(GDDR6_DELAY_REG),

        delay_address_o => delay_address_o,
        delay_o => delay_o,
        delay_up_down_n_o => delay_up_down_n_o,
        delay_byteslip_o => delay_byteslip_o,
        delay_read_write_n_o => delay_read_write_n_o,
        delay_i => delay_i,
        delay_strobe_o => delay_strobe_o,
        delay_ack_i => delay_ack_i
    );


    exchange : entity work.gddr6_setup_exchange port map (
        reg_clk_i => reg_clk_i,
        ck_clk_i => ck_clk_i,
        ck_clk_ok_i => ck_clk_ok,

        write_strobe_i => write_strobe_i(GDDR6_EXCHANGE_REGS),
        write_data_i => write_data_i(GDDR6_EXCHANGE_REGS),
        write_ack_o => write_ack_o(GDDR6_EXCHANGE_REGS),
        read_strobe_i => read_strobe_i(GDDR6_EXCHANGE_REGS),
        read_data_o => read_data_o(GDDR6_EXCHANGE_REGS),
        read_ack_o => read_ack_o(GDDR6_EXCHANGE_REGS),

        phy_ca_o => phy_ca_o,
        phy_ca3_o => phy_ca3_o,
        phy_cke_n_o => phy_cke_n_o,
        phy_output_enable_o => phy_output_enable_o,
        phy_data_o => phy_data_o,
        phy_data_i => phy_data_i,
        phy_edc_in_i => phy_edc_in_i,
        phy_edc_out_i => phy_edc_out_i
    );
end;
