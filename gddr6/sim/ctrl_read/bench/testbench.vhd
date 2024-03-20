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

    constant PHY_INPUT_DELAY : natural := 5;

    signal axi_request : axi_read_request_t;
    signal axi_response : axi_read_response_t;
    signal read_request : core_request_t;
    signal read_ready : std_ulogic;
    signal read_sent : std_ulogic := '0';
    signal read_lookahead : bank_open_t;
    signal edc_in : vector_array(7 downto 0)(7 downto 0);
    signal edc_read : vector_array(7 downto 0)(7 downto 0);


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

    read : entity work.gddr6_ctrl_read generic map (
        PHY_INPUT_DELAY => PHY_INPUT_DELAY
    ) port map (
        clk_i => clk,

        axi_request_i => axi_request,
        axi_response_o => axi_response,
        read_request_o => read_request,
        read_ready_i => read_ready,
        read_sent_i => read_sent,
        read_lookahead_o => read_lookahead,
        edc_in_i => edc_in,
        edc_read_i => edc_read
    );

    -- AXI producer
    process
        procedure send(
            address : unsigned(24 downto 0); count : unsigned(4 downto 0)) is
        begin
            axi_request.ra_address <= address;
            axi_request.ra_count <= count;
            axi_request.ra_valid <= '1';
            loop
                clk_wait;
                exit when axi_response.ra_ready;
            end loop;
            axi_request.ra_address <= (others => 'U');
            axi_request.ra_count <= (others => 'U');
            axi_request.ra_valid <= '0';
        end;

    begin
        axi_request.ra_valid <= '0';
        axi_request.ral_valid <= '0';

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

    delay_sent : entity work.fixed_delay generic map (
        DELAY => 4
    ) port map (
        clk_i => clk,
        data_i(0) => read_request.valid and read_ready,
        data_o(0) => read_sent
    );
end;
