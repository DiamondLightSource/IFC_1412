-- Clock crossing FIFO for Read/Write address

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_axi_defs.all;

entity gddr6_axi_address_fifo is
    generic (
        FIFO_BITS : natural := 10
    );
    port (
        axi_clk_i : in std_ulogic;
        axi_address_i : in address_t;
        axi_ready_o : out std_ulogic;

        ctrl_clk_i : in std_ulogic;
        ctrl_address_o : out address_t;
        ctrl_ready_i : in std_ulogic
    );
end;

architecture arch of gddr6_axi_address_fifo is
    subtype ADDRESS_RANGE is natural range 24 downto 0;
    subtype COUNT_RANGE is natural range 29 downto 25;
    constant DATA_WIDTH : natural := 30;

begin
    fifo : entity work.async_fifo generic map (
        FIFO_BITS => FIFO_BITS,
        DATA_WIDTH => DATA_WIDTH
    ) port map (
        write_clk_i => axi_clk_i,
        write_valid_i => axi_address_i.valid,
        write_ready_o => axi_ready_o,
        write_data_i(ADDRESS_RANGE) => std_ulogic_vector(axi_address_i.address),
        write_data_i(COUNT_RANGE) => std_ulogic_vector(axi_address_i.count),

        read_clk_i => ctrl_clk_i,
        read_valid_o => ctrl_address_o.valid,
        read_ready_i => ctrl_ready_i,
        unsigned(read_data_o(ADDRESS_RANGE)) => ctrl_address_o.address,
        unsigned(read_data_o(COUNT_RANGE)) => ctrl_address_o.count
    );
end;
