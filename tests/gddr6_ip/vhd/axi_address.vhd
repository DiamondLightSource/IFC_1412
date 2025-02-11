-- AXI address generation

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;

use work.gddr6_defs.all;

entity axi_address is
    port (
        clk_i : in std_ulogic;

        address_i : in unsigned(25 downto 0);
        write_count_i : in unsigned(5 downto 0);
        read_count_i : in unsigned(5 downto 0);

        start_axi_write_i : in std_ulogic;
        start_axi_read_i : in std_ulogic;

        -- Communication to AXI
        write_address_o : out axi_address_t := IDLE_AXI_ADDRESS;
        write_address_ready_i : in std_ulogic;
        read_address_o : out axi_address_t := IDLE_AXI_ADDRESS;
        read_address_ready_i : in std_ulogic
    );
end;

architecture arch of axi_address is
begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            if start_axi_write_i then
                write_address_o <= (
                    id => X"0",
                    addr => address_i & 6X"0",
                    len => "00" & write_count_i,
                    size => "110",
                    burst => "01",
                    valid => '1'
                );
            elsif write_address_ready_i then
                write_address_o.valid <= '0';
            end if;

            if start_axi_read_i then
                read_address_o <= (
                    id => X"0",
                    addr => address_i & 6X"0",
                    len => "00" & read_count_i,
                    size => "110",
                    burst => "01",
                    valid => '1'
                );
            elsif read_address_ready_i then
                read_address_o.valid <= '0';
            end if;
        end if;
    end process;
end;
