-- FIFO for Write response

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_axi_defs.all;

entity gddr6_axi_write_response_fifo is
    generic (
        COMMAND_FIFO_BITS : natural := 10
    );
    port (
        clk_i : in std_ulogic;

        response_i : in burst_response_t;
        ready_o : out std_ulogic;

        response_o : out burst_response_t;
        ready_i : in std_ulogic
    );
end;

architecture arch of gddr6_axi_write_response_fifo is
    subtype ID_RANGE is natural range 3 downto 0;
    subtype COUNT_RANGE is natural range 8 downto 4;
    constant INVALID_RANGE : natural := 9;
    constant DATA_WIDTH : natural := 10;

begin
    fifo : entity work.fifo generic map (
        FIFO_BITS => COMMAND_FIFO_BITS,
        DATA_WIDTH => DATA_WIDTH
    ) port map (
        clk_i => clk_i,

        write_valid_i => response_i.valid,
        write_ready_o => ready_o,
        write_data_i(ID_RANGE) => response_i.id,
        write_data_i(COUNT_RANGE) => std_ulogic_vector(response_i.count),
        write_data_i(INVALID_RANGE) => response_i.invalid_burst,

        read_valid_o => response_o.valid,
        read_ready_i => ready_i,
        read_data_o(ID_RANGE) => response_o.id,
        unsigned(read_data_o(COUNT_RANGE)) => response_o.count,
        read_data_o(INVALID_RANGE) => response_o.invalid_burst
    );
end;
