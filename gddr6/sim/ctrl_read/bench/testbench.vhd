library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

use work.gddr6_ctrl_core_defs.all;
use work.gddr6_defs.all;

entity testbench is
end testbench;


architecture arch of testbench is
    signal clk : std_ulogic := '0';

    signal axi_address : unsigned(24 downto 0);
    signal axi_valid : std_ulogic;
    signal axi_ready : std_ulogic := '1';
    signal read_request : core_request_t;
    signal read_ready : std_ulogic;


    procedure clk_wait(count : natural := 1) is
    begin
        for i in 1 to count loop
            wait until rising_edge(clk);
        end loop;
    end;

    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

begin
    clk <= not clk after 2 ns;

    read : entity work.gddr6_ctrl_read port map (
        clk_i => clk,

        axi_address_i => axi_address,
        axi_valid_i => axi_valid,
        axi_ready_o => axi_ready,
        read_request_o => read_request,
        read_ready_i => read_ready
    );

    -- AXI producer
    process
        procedure send(
            address : unsigned(24 downto 0); count : unsigned(4 downto 0)) is
        begin
            axi_address <= address;
            axi_valid <= '1';
            loop
                clk_wait;
                exit when axi_ready;
            end loop;
            axi_address <= (others => 'U');
            axi_valid <= '0';
        end;

    begin
        axi_valid <= '0';

        clk_wait(5);

        send(25X"1234567", 5X"10");
        send(25X"1234568", 5X"0F");
        send(25X"1234569", 5X"0E");

        clk_wait(5);
        send(25X"123456A", 5X"0D");

        wait;
    end process;

    -- Core consumer
    process begin
        read_ready <= '0';
        clk_wait;

        loop
            loop
                clk_wait;
                exit when read_request.valid;
            end loop;
            read_ready <= '1';
            clk_wait;
            read_ready <= '0';
        end loop;

        wait;
    end process;
end;
