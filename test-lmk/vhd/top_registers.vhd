-- Test register interface

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.register_defines.all;
use work.version.all;

entity top_registers is
    port (
        clk_i : in std_ulogic;

        -- System register interface
        write_strobe_i : in std_ulogic_vector(TOP_REGS_RANGE);
        write_data_i : in reg_data_array_t(TOP_REGS_RANGE);
        write_ack_o : out std_ulogic_vector(TOP_REGS_RANGE);
        read_strobe_i : in std_ulogic_vector(TOP_REGS_RANGE);
        read_data_o : out reg_data_array_t(TOP_REGS_RANGE);
        read_ack_o : out std_ulogic_vector(TOP_REGS_RANGE);

        -- LMK config and status
        lmk_command_select_o : out std_ulogic;
        lmk_status_i : in std_ulogic_vector(1 downto 0);
        lmk_reset_o : out std_ulogic;
        lmk_sync_o : out std_ulogic;

        -- SPI interface to LMK
        lmk_write_strobe_o : out std_ulogic;
        lmk_write_ack_i : in std_ulogic;
        lmk_read_write_n_o : out std_ulogic;
        lmk_address_o : out std_ulogic_vector(14 downto 0);
        lmk_data_o : out std_ulogic_vector(7 downto 0);
        lmk_write_select_o : out std_ulogic;
        lmk_read_strobe_o : out std_ulogic;
        lmk_read_ack_i : in std_ulogic;
        lmk_data_i : in std_ulogic_vector(7 downto 0);

        -- Frequency counters
        clock_counts_i : in unsigned_array;
        clock_update_i : in std_ulogic
    );
end;

architecture arch of top_registers is
    signal event_bits : reg_data_t;
    signal status_bits : reg_data_t;
    signal config_bits : reg_data_t;
    signal lmk_write_bits : reg_data_t;
    signal lmk_read_bits : reg_data_t;

begin
    read_data_o(TOP_GIT_VERSION_REG) <= (
        TOP_GIT_VERSION_SHA_BITS => to_std_ulogic_vector_u(GIT_VERSION, 28),
        TOP_GIT_VERSION_DIRTY_BIT => to_std_ulogic(GIT_DIRTY),
        others => '0'
    );
    read_ack_o(TOP_GIT_VERSION_REG) <= '1';
    write_ack_o(TOP_GIT_VERSION_REG) <= '1';

    events :  entity work.register_events port map (
        clk_i => clk_i,
        read_strobe_i => read_strobe_i(TOP_EVENTS_REG),
        read_data_o => read_data_o(TOP_EVENTS_REG),
        read_ack_o => read_ack_o(TOP_EVENTS_REG),
        pulsed_bits_i => event_bits
    );
    write_ack_o(TOP_EVENTS_REG) <= '1';

    read_data_o(TOP_STATUS_REG) <= status_bits;
    read_ack_o(TOP_STATUS_REG) <= '1';
    write_ack_o(TOP_STATUS_REG) <= '1';

    config : entity work.register_file_rw port map (
        clk_i => clk_i,
        write_strobe_i(0) => write_strobe_i(TOP_CONFIG_REG),
        write_data_i(0) => write_data_i(TOP_CONFIG_REG),
        write_ack_o(0) => write_ack_o(TOP_CONFIG_REG),
        read_strobe_i(0) => read_strobe_i(TOP_CONFIG_REG),
        read_data_o(0) => read_data_o(TOP_CONFIG_REG),
        read_ack_o(0) => read_ack_o(TOP_CONFIG_REG),
        register_data_o(0) => config_bits
    );

    read_data_o(TOP_LMK04616_REG) <= lmk_read_bits;
    lmk_read_strobe_o <= read_strobe_i(TOP_LMK04616_REG);
    read_ack_o(TOP_LMK04616_REG) <= lmk_read_ack_i;
    lmk_write_strobe_o <= write_strobe_i(TOP_LMK04616_REG);
    lmk_write_bits <= write_data_i(TOP_LMK04616_REG);
    write_ack_o(TOP_LMK04616_REG) <= lmk_write_ack_i;

    read_data_o(TOP_CLOCK_FREQ_REGS) <= reg_data_array_t(clock_counts_i);
    read_ack_o(TOP_CLOCK_FREQ_REGS) <= (others => '1');
    write_ack_o(TOP_CLOCK_FREQ_REGS) <= (others => '1');


    -- -------------------------------------------------------------------------


    event_bits <= (
        TOP_EVENTS_COUNT_UPDATE_BIT => clock_update_i,
        others => '0');

    status_bits <= (
        TOP_STATUS_LMK_STATUS_BITS => lmk_status_i,
        others => '0');

    lmk_command_select_o <= config_bits(TOP_CONFIG_LMK_SELECT_BIT);
    lmk_reset_o <= config_bits(TOP_CONFIG_LMK_RESET_BIT);
    lmk_sync_o <= config_bits(TOP_CONFIG_LMK_SYNC_BIT);

    lmk_read_write_n_o <= lmk_write_bits(TOP_LMK04616_R_WN_BIT);
    lmk_data_o <= lmk_write_bits(TOP_LMK04616_DATA_BITS);
    lmk_address_o <= lmk_write_bits(TOP_LMK04616_ADDRESS_BITS);
    lmk_write_select_o <= lmk_write_bits(TOP_LMK04616_SELECT_BIT);
    lmk_read_bits <= (
        TOP_LMK04616_DATA_BITS => lmk_data_i,
        others => '0');
end;
