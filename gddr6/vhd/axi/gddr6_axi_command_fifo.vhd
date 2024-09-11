-- Read command fifo

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_axi_defs.all;

entity gddr6_axi_command_fifo is
    generic (
        COMMAND_FIFO_BITS : natural
    );
    port (
        clk_i : in std_ulogic;

        command_i : in burst_command_t;
        ready_o : out std_ulogic;

        command_o : out burst_command_t;
        ready_i : in std_ulogic
    );
end;

architecture arch of gddr6_axi_command_fifo is
    subtype ID_RANGE is natural range 3 downto 0;
    subtype COUNT_RANGE is natural range 11 downto 4;
    subtype OFFSET_RANGE is natural range 18 downto 12;
    subtype STEP_RANGE is natural range 25 downto 19;
    constant INVALID_RANGE : natural := 26;
    constant DATA_WIDTH : natural := 27;

begin
    fifo : entity work.fifo generic map (
        FIFO_BITS => COMMAND_FIFO_BITS,
        DATA_WIDTH => DATA_WIDTH
    ) port map (
        clk_i => clk_i,

        write_valid_i => command_i.valid,
        write_ready_o => ready_o,
        write_data_i(ID_RANGE) => command_i.id,
        write_data_i(COUNT_RANGE) => std_ulogic_vector(command_i.count),
        write_data_i(OFFSET_RANGE) => std_ulogic_vector(command_i.offset),
        write_data_i(STEP_RANGE) => std_ulogic_vector(command_i.step),
        write_data_i(INVALID_RANGE) => command_i.invalid_burst,

        read_valid_o => command_o.valid,
        read_ready_i => ready_i,
        read_data_o(ID_RANGE) => command_o.id,
        unsigned(read_data_o(COUNT_RANGE)) => command_o.count,
        unsigned(read_data_o(OFFSET_RANGE)) => command_o.offset,
        unsigned(read_data_o(STEP_RANGE)) => command_o.step,
        read_data_o(INVALID_RANGE) => command_o.invalid_burst
    );
end;
