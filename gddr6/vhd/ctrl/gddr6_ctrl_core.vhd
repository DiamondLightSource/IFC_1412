-- Core command arbitration and dispatch

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_command_defs.all;
use work.gddr6_ctrl_core_defs.all;

entity gddr6_ctrl_core is
    port (
        clk_i : in std_ulogic;

        -- Write request with handshake
        write_request_i : in core_request_t;
        write_ready_o : out std_ulogic;
        -- This is strobed when the requested command is actually sent and may
        -- occur many ticks after the command has been accepted
        write_sent_o : out std_ulogic;

        -- Read request with handshake
        read_request_i : in core_request_t;
        read_ready_o : out std_ulogic;
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

begin
    banks : entity work.gddr6_ctrl_banks port map (
    );

    command : entity work.gddr6_ctrl_command port map (
        clk_i => clk_i,

        bank_status_i => 
        bank_response_o => 

        direction_i => 

        write_request_i => write_request_i,
        write_ready_o => write_ready_o,
        write_sent_o => write_sent_o,

        read_request_i => read_request_i,
        read_ready_o => read_ready_o,
        read_sent_o => read_sent_o,

        admin_command_i => 
        admin_command_valid_i => 
        admin_command_ready_o => 

        open_bank_valid_o => 
        open_bank_o => 
        open_bank_row_o => 

        ca_command_o => 
    );


--     refresh : entity work.gddr6_ctrl_refresh port map (
--     );
-- 
-- 
--     arb : entity work.gddr6_ctrl_arb port map (
--     );
-- 
-- 
--     process (clk_i) begin
--         if rising_edge(clk_i) then
-- 
--         end if;
--     end process;
end;
