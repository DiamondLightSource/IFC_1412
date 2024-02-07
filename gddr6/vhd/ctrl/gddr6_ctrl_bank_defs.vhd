-- Definitions for banks

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package gddr6_ctrl_bank_defs is
    type bank_command_t is (
        CMD_IDLE, CMD_RD, CMD_WR, CMD_ACT,
        CMD_PREpb, CMD_PREab, CMD_REFp2b, CMD_REFab);
end;
