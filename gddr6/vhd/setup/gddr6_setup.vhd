-- Top level control for gddr6 setup

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.gddr6_register_defines.all;

entity gddr6_setup is
    port (
        ck_clk_i : in std_ulogic;       -- CK clock
        riu_clk_i : in std_ulogic;      -- RIU clock
        ck_clk_ok_i : in std_ulogic;    -- CK and RIU clocks ok
        reg_clk_i : in std_ulogic;      -- Register clock

        -- Register interface for data access
        write_strobe_i : in std_ulogic_vector(GDDR6_REGS_RANGE);
        write_data_i : in reg_data_array_t(GDDR6_REGS_RANGE);
        write_ack_o : out std_ulogic_vector(GDDR6_REGS_RANGE);
        read_strobe_i : in std_ulogic_vector(GDDR6_REGS_RANGE);
        read_data_o : out reg_data_array_t(GDDR6_REGS_RANGE);
        read_ack_o : out std_ulogic_vector(GDDR6_REGS_RANGE);

        -- PHY interface on ck_clk_i, connected to gddr6_phy
        phy_ca_o : out vector_array(0 to 1)(9 downto 0);
        phy_ca3_o : out std_ulogic_vector(0 to 3);
        phy_cke_n_o : out std_ulogic;
        phy_dq_t_o : out std_ulogic;
        phy_data_o : out std_ulogic_vector(511 downto 0);
        phy_data_i : in std_ulogic_vector(511 downto 0);
        phy_edc_in_i : in vector_array(7 downto 0)(7 downto 0);
        phy_edc_out_i : in vector_array(7 downto 0)(7 downto 0);

        -- RIU interface on riu_clk_i
        riu_addr_o : out unsigned(9 downto 0);
        riu_wr_data_o : out std_ulogic_vector(15 downto 0);
        riu_rd_data_i : in std_ulogic_vector(15 downto 0);
        riu_wr_en_o : out std_ulogic;
        riu_strobe_o : out std_ulogic;
        riu_ack_i : in std_ulogic;
        riu_error_i : in std_ulogic;
        riu_vtc_handshake_o : out std_ulogic;

        -- Controls to PHY
        ck_reset_o : out std_ulogic;
        ck_unlock_i : in std_ulogic;
        fifo_ok_i : in std_ulogic;
        sg_resets_n_o : out std_ulogic_vector(0 to 1);

        -- General PHY configuration
        enable_cabi_o : out std_ulogic;
        enable_dbi_o : out std_ulogic;
        rx_slip_o : out unsigned_array(0 to 1)(2 downto 0);
        tx_slip_o : out unsigned_array(0 to 1)(2 downto 0)
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
        fifo_ok_i => fifo_ok_i,
        sg_resets_n_o => sg_resets_n_o,
        enable_cabi_o => enable_cabi_o,
        enable_dbi_o => enable_dbi_o,
        rx_slip_o => rx_slip_o,
        tx_slip_o => tx_slip_o
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
        phy_dq_t_o => phy_dq_t_o,
        phy_data_o => phy_data_o,
        phy_data_i => phy_data_i,
        phy_edc_in_i => phy_edc_in_i,
        phy_edc_out_i => phy_edc_out_i
    );


    riu : entity work.gddr6_setup_riu port map (
        reg_clk_i => reg_clk_i,
        riu_clk_i => riu_clk_i,
        riu_clk_ok_i => ck_clk_ok,

        write_strobe_i => write_strobe_i(GDDR6_RIU_REG),
        write_data_i => write_data_i(GDDR6_RIU_REG),
        write_ack_o => write_ack_o(GDDR6_RIU_REG),
        read_strobe_i => read_strobe_i(GDDR6_RIU_REG),
        read_data_o => read_data_o(GDDR6_RIU_REG),
        read_ack_o => read_ack_o(GDDR6_RIU_REG),

        riu_addr_o => riu_addr_o,
        riu_wr_data_o => riu_wr_data_o,
        riu_rd_data_i => riu_rd_data_i,
        riu_wr_en_o => riu_wr_en_o,
        riu_strobe_o => riu_strobe_o,
        riu_ack_i => riu_ack_i,
        riu_error_i => riu_error_i,
        riu_vtc_handshake_o => riu_vtc_handshake_o
    );
end;
