-- Core command arbitration and dispatch

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_commands.all;
use work.gddr6_ctrl_core_defs.all;

entity gddr6_ctrl_core is
    port (
        clk_i : in std_ulogic;

        -- Write request with handshake
        write_request_i : in core_request_t;
        write_request_extra_i : in std_ulogic;
        write_request_ready_o : out std_ulogic;
        -- This is strobed when the requested command is actually sent and may
        -- occur many ticks after the command has been accepted
        write_sent_o : out std_ulogic;

        -- Read request with handshake
        read_request_i : in core_request_t;
        read_request_ready_o : out std_ulogic;
        -- Command sent acknowledge
        read_sent_o : out std_ulogic;

        -- Lookahead for write and read
        write_lookahead_i : in core_lookahead_t;
        read_lookahead_i : in core_lookahead_t;

        -- CA Commands out to PHY
        ca_command_o : ca_command_t
    );
end;

architecture arch of gddr6_ctrl_core is
    type direction_t is (DIRECTION_IDLE, DIRECTION_READ, DIRECTION_WRITE);
    type direction : direction_t := DIRECTION_IDLE;

    signal request : core_request_t;
    signal lookahead : core_request_t;
    signal write_byte_mask : std_ulogic;

begin
    banks : entity work.gddr6_ctrl_banks port map (
    );


    refresh : entity work.gddr6_ctrl_refresh port map (
    );


    arb : entity work.gddr6_ctrl_arb port map (
    );


    process (clk_i) begin
        if rising_edge(clk_i) then

        end if;
    end process;
end;
