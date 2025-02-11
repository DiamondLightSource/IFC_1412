-- Test register interface

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
-- use work.defines.all;

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

        fmc1_leds_o : out std_ulogic_vector(1 to 8);
        fmc2_leds_o : out std_ulogic_vector(1 to 8);
        fp_led2a_o : out std_ulogic;
        fp_led2b_o : out std_ulogic
    );
end;

architecture arch of top_registers is
    signal control_bits : reg_data_t;

begin
    write_ack_o(TOP_GIT_VERSION_REG) <= '1';
    read_ack_o(TOP_GIT_VERSION_REG) <= '1';
    read_data_o(TOP_GIT_VERSION_REG) <= (
        TOP_GIT_VERSION_SHA_BITS => to_std_ulogic_vector_u(GIT_VERSION, 28),
        TOP_GIT_VERSION_DIRTY_BIT => to_std_ulogic(GIT_DIRTY),
        others => '0'
    );

    control : entity work.register_file_rw port map (
        clk_i => clk_i,
        write_strobe_i(0) => write_strobe_i(TOP_LEDS_REG),
        write_data_i(0) => write_data_i(TOP_LEDS_REG),
        write_ack_o(0) => write_ack_o(TOP_LEDS_REG),
        read_strobe_i(0) => read_strobe_i(TOP_LEDS_REG),
        read_data_o(0) => read_data_o(TOP_LEDS_REG),
        read_ack_o(0) => read_ack_o(TOP_LEDS_REG),
        register_data_o(0) => control_bits
    );

    process (clk_i) begin
        if rising_edge(clk_i) then
            fmc1_leds_o <= reverse(control_bits(TOP_LEDS_FMC1_BITS));
            fmc2_leds_o <= reverse(control_bits(TOP_LEDS_FMC2_BITS));
            fp_led2a_o <= control_bits(TOP_LEDS_LED2A_BIT);
            fp_led2b_o <= control_bits(TOP_LEDS_LED2B_BIT);
        end if;
    end process;
end;
