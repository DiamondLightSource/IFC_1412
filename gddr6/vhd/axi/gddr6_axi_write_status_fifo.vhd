-- Clock crossing FIFO with reservation for Write completion status

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity gddr6_axi_write_status_fifo is
    generic (
        DATA_FIFO_BITS : natural;
        MAX_DELAY : real
    );
    port (
        -- AXI interface
        axi_clk_i : in std_ulogic;
        -- Write status from control
        axi_ok_o : out std_ulogic;
        axi_ok_valid_o : out std_ulogic := '0';
        axi_ok_ready_i : in std_ulogic;

        -- CTRL interface
        ctrl_clk_i : in std_ulogic;
        -- Slot reservation for returning write completion status
        ctrl_reserve_valid_o : out std_ulogic;
        ctrl_reserve_ready_i : in std_ulogic;
        -- Write completion status
        ctrl_ok_i : in std_ulogic;
        ctrl_ok_valid_i : in std_ulogic
    );
end;

architecture arch of gddr6_axi_write_status_fifo is
    subtype ADDRESS_RANGE is natural range DATA_FIFO_BITS-1 downto 0;
    signal write_address : unsigned(ADDRESS_RANGE);
    signal read_address : unsigned(ADDRESS_RANGE);

    subtype SG_FIFO_RANGE is natural range 0 to 2**DATA_FIFO_BITS - 1;
    signal ok_fifo : std_ulogic_vector(SG_FIFO_RANGE);
    signal read_enable : std_ulogic;
    signal read_valid : std_ulogic;

begin
    async_address : entity work.async_fifo_address generic map (
        ADDRESS_WIDTH => DATA_FIFO_BITS,
        ENABLE_READ_RESERVE => false,
        ENABLE_WRITE_RESERVE => true,
        MAX_DELAY => MAX_DELAY
    ) port map (
        write_clk_i => ctrl_clk_i,
        write_reserve_i => ctrl_reserve_ready_i,
        write_access_i => ctrl_ok_valid_i,
        write_ready_o => ctrl_reserve_valid_o,
        write_access_address_o => write_address,

        read_clk_i => axi_clk_i,
        read_access_i => read_enable,
        read_valid_o => read_valid,
        read_access_address_o => read_address
    );

    fifo : entity work.memory_array_dual generic map (
        ADDR_BITS => DATA_FIFO_BITS,
        DATA_BITS => 1,
        MEM_STYLE => "BLOCK"
    ) port map (
        write_clk_i => ctrl_clk_i,
        write_strobe_i => ctrl_ok_valid_i,
        write_addr_i => write_address,
        write_data_i(0) => ctrl_ok_i,

        read_clk_i => axi_clk_i,
        read_strobe_i => read_enable,
        read_addr_i => read_address,
        read_data_o(0) => axi_ok_o
    );

    read_enable <= read_valid and (axi_ok_ready_i or not axi_ok_valid_o);
    process (axi_clk_i) begin
        if rising_edge(axi_clk_i) then
            if read_enable then
                axi_ok_valid_o <= '1';
            elsif axi_ok_ready_i then
                axi_ok_valid_o <= '0';
            end if;
        end if;
    end process;
end;
