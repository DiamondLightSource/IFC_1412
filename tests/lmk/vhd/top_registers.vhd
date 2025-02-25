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
        write_strobe_i : in std_ulogic_vector(TOP_REGISTERS_REGS);
        write_data_i : in reg_data_array_t(TOP_REGISTERS_REGS);
        write_ack_o : out std_ulogic_vector(TOP_REGISTERS_REGS);
        read_strobe_i : in std_ulogic_vector(TOP_REGISTERS_REGS);
        read_data_o : out reg_data_array_t(TOP_REGISTERS_REGS);
        read_ack_o : out std_ulogic_vector(TOP_REGISTERS_REGS);

        -- Frequency counters
        clock_counts_i : in unsigned_array;
        clock_update_i : in std_ulogic
    );
end;

architecture arch of top_registers is
    signal event_bits : reg_data_t;

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

    read_data_o(TOP_CLOCK_FREQ_REGS) <= reg_data_array_t(clock_counts_i);
    read_ack_o(TOP_CLOCK_FREQ_REGS) <= (others => '1');
    write_ack_o(TOP_CLOCK_FREQ_REGS) <= (others => '1');


    -- -------------------------------------------------------------------------


    event_bits <= (
        TOP_EVENTS_COUNT_UPDATE_BIT => clock_update_i,
        others => '0');
end;
