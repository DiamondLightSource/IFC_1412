library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

use work.gddr6_ctrl_core_defs.all;

entity testbench is
end testbench;


architecture arch of testbench is
    signal clk : std_ulogic := '0';

    constant PHY_INPUT_DELAY : natural := 5;

    signal ra_address : unsigned(24 downto 0);
    signal ra_count : unsigned(4 downto 0);
    signal ra_valid : std_ulogic;
    signal ra_ready : std_ulogic;
    signal ral_address : unsigned(24 downto 0);
    signal ral_valid : std_ulogic;
    signal rd_valid : std_ulogic := '0';
    signal rd_ok : std_ulogic;
    signal rd_ok_valid : std_ulogic := '0';

    signal request : core_request_t;
    signal request_ready : std_ulogic;
    signal lookahead : core_lookahead_t;

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

        ra_address_i => ra_address,
        ra_count_i => ra_count,
        ra_valid_i => ra_valid,
        ra_ready_o => ra_ready,
        ral_address_i => ral_address,
        ral_valid_i => ral_valid,
        rd_valid_o => rd_valid,
        rd_ok_o => rd_ok,
        rd_ok_valid_o => rd_ok_valid,

        request_o => request,
        request_ready_i => request_ready,
        lookahead_o => lookahead,

        edc_in_i => edc_in,
        edc_read_i => edc_read
    );

    -- AXI producer
    process
        procedure send(
            address : unsigned(24 downto 0); count : unsigned(4 downto 0)) is
        begin
            ra_address <= address;
            ra_count <= count;
            ra_valid <= '1';
            loop
                clk_wait;
                exit when ra_ready;
            end loop;
            ra_address <= (others => 'U');
            ra_count <= (others => 'U');
            ra_valid <= '0';
        end;

    begin
        ra_valid <= '0';
        ral_valid <= '0';

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
        request_ready <= '0';
        clk_wait;

        loop
            loop
                clk_wait;
                exit when request.valid;
            end loop;
            request_ready <= '1';
            clk_wait;
            request_ready <= '0';
        end loop;

        wait;
    end process;
end;
