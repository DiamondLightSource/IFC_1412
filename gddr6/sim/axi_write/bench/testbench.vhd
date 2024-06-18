library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_axi_defs.all;

entity testbench is
end testbench;


architecture arch of testbench is
    constant AXI_PERIOD : time := 4.95 ns;
--     constant AXI_PERIOD : time := 0.95 ns;
    constant CTRL_PERIOD : time := 4 ns;

    constant FIFO_BITS : natural := 4;

    signal axi_clk : std_ulogic := '0';
    signal ctrl_clk : std_ulogic := '0';

    procedure clk_wait(signal clk : in std_ulogic; count : natural := 1) is
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


    constant INVALID_AXI_ADDRESS : axi_address_t := (
        id => (others => 'U'),
        addr => (others => 'U'),
        len => (others => 'U'),
        size => (others => 'U'),
        burst => (others => 'U'),
        valid => '0'
    );

    constant INVALID_AXI_DATA : axi_write_data_t := (
        data => (others => 'U'),
        strb => (others => 'U'),
        last => 'U',
        valid => '0'
    );

    constant INVALID_CTRL_RESPONSE : axi_ctrl_write_response_t := (
        wa_ready => '1',
        wd_advance => '1',
        wd_ready => '1',
        wr_ok => 'U',
        wr_ok_valid => '0'
    );


    signal axi_address : axi_address_t := INVALID_AXI_ADDRESS;
    signal axi_address_ready : std_ulogic;
    signal axi_data : axi_write_data_t := INVALID_AXI_DATA;
    signal axi_data_ready : std_ulogic;
    signal axi_response : axi_write_response_t;
    signal axi_response_ready : std_ulogic := '0';
    signal ctrl_request : axi_ctrl_write_request_t;
    signal ctrl_response : axi_ctrl_write_response_t := INVALID_CTRL_RESPONSE;

begin
    axi_clk <= not axi_clk after AXI_PERIOD;
    ctrl_clk <= not ctrl_clk after CTRL_PERIOD;

    axi_write : entity work.gddr6_axi_write generic map (
        FIFO_BITS => FIFO_BITS
    ) port map (
        axi_clk_i => axi_clk,
        axi_address_i => axi_address,
        axi_address_ready_o => axi_address_ready,
        axi_data_i => axi_data,
        axi_data_ready_o => axi_data_ready,
        axi_response_o => axi_response,
        axi_response_ready_i => axi_response_ready,

        ctrl_clk_i => ctrl_clk,
        ctrl_request_o => ctrl_request,
        ctrl_response_i => ctrl_response
    );


    -- Sent address requests
    process
        procedure clk_wait(count : natural := 1) is
        begin
            clk_wait(axi_clk, count);
        end;

        procedure send(
            id : std_logic_vector(3 downto 0);
            addr : unsigned(31 downto 0);
            len : unsigned(7 downto 0);
            size : unsigned(2 downto 0)) is
        begin
            axi_address <= (
                id => id,
                addr => addr,
                len => len,
                size => size,
                burst => "01",
                valid => '1'
            );
            loop
                clk_wait;
                exit when axi_address_ready;
            end loop;
            axi_address <= INVALID_AXI_ADDRESS;
        end;

    begin
        -- A simple burst: two SG bursts, four AXI beats
        send(X"1", X"0000_0100", X"03", "110");
--         send(X"1", X"0000_0100", X"03", "110");

        wait;
    end process;


    -- Send data
end;
