-- AXI W stream interface

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_axi_defs.all;

entity gddr6_axi_write_data is
    port (
        clk_i : in std_ulogic;

        -- FIFO from AXI RA data interface
        fifo_command_i : in burst_command_t;
        fifo_ready_o : out std_ulogic := '0';

        -- Data FIFO
        fifo_data_o : out write_data_t := IDLE_WRITE_DATA;
        fifo_ready_i : in std_ulogic;

        -- AXI W interface
        axi_data_i : in axi_write_data_t;
        axi_ready_o : out std_ulogic := '0'
    );
end;

architecture arch of gddr6_axi_write_data is
begin
end;
