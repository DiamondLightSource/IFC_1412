-- Test register interface

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.register_defines.all;
use work.version.all;

entity system_registers is
    port (
        clk_i : in std_ulogic;

        -- System register interface
        write_strobe_i : in std_ulogic_vector(SYS_CONTROL_REGS);
        write_data_i : in reg_data_array_t(SYS_CONTROL_REGS);
        write_ack_o : out std_ulogic_vector(SYS_CONTROL_REGS);
        read_strobe_i : in std_ulogic_vector(SYS_CONTROL_REGS);
        read_data_o : out reg_data_array_t(SYS_CONTROL_REGS);
        read_ack_o : out std_ulogic_vector(SYS_CONTROL_REGS)
    );
end;

architecture arch of system_registers is

begin
    read_data_o(SYS_GIT_VERSION_REG) <= (
        SYS_GIT_VERSION_SHA_BITS => to_std_ulogic_vector_u(GIT_VERSION, 28),
        SYS_GIT_VERSION_DIRTY_BIT => to_std_ulogic(GIT_DIRTY),
        others => '0'
    );
    read_ack_o(SYS_GIT_VERSION_REG) <= '1';
    write_ack_o(SYS_GIT_VERSION_REG) <= '1';

end;
