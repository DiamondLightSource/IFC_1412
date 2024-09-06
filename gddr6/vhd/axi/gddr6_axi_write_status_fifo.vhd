-- Clock crossing FIFO for Write completion status

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity gddr6_axi_write_status_fifo is
    generic (
        FIFO_BITS : natural := 10
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
    signal write_address : unsigned(FIFO_BITS-2 downto 0);
    signal read_address : unsigned(FIFO_BITS-2 downto 0);

    subtype SG_FIFO_RANGE is natural range 0 to 2**(FIFO_BITS-1) - 1;
    signal ok_fifo : std_ulogic_vector(SG_FIFO_RANGE);
    signal read_enable : std_ulogic;
    signal read_valid : std_ulogic;

begin
    async_address : entity work.async_fifo_address generic map (
        ADDRESS_WIDTH => FIFO_BITS - 1,
        ENABLE_READ_RESERVE => false,
        ENABLE_WRITE_RESERVE => true
    ) port map (
        write_clk_i => ctrl_clk_i,
        write_reserve_i => ctrl_reserve_ready_i,
        write_access_i => ctrl_ok_valid_i,
        write_ready_o => ctrl_reserve_valid_o,
        write_access_address_o => write_address,

        read_clk_i => axi_clk_i,
        read_access_i => read_enable,
        read_ready_o => read_valid,
        read_access_address_o => read_address
    );

    read_enable <= read_valid and (axi_ok_ready_i or not axi_ok_valid_o);
    process (axi_clk_i) begin
        if rising_edge(axi_clk_i) then
            if read_enable then
                axi_ok_o <= ok_fifo(to_integer(read_address));
                axi_ok_valid_o <= '1';
            elsif axi_ok_ready_i then
                axi_ok_valid_o <= '0';
            end if;
        end if;
    end process;

    process (ctrl_clk_i) begin
        if rising_edge(ctrl_clk_i) then
            if ctrl_ok_valid_i then
                ok_fifo(to_integer(write_address)) <= ctrl_ok_i;
            end if;
        end if;
    end process;
end;
