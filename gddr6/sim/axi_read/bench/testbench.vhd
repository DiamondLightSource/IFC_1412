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

    constant FIFO_BITS : natural := 5;

    signal axi_clk : std_ulogic := '0';
    signal ctrl_clk : std_ulogic := '0';

    procedure clk_wait(signal clk : in std_ulogic; count : natural := 1) is
    begin
        for i in 1 to count loop
            wait until rising_edge(clk);
        end loop;
    end;

    constant INVALID_AXI_ADDRESS : axi_address_t := (
        id => (others => 'U'),
        addr => (others => 'U'),
        len => (others => 'U'),
        size => (others => 'U'),
        burst => (others => 'U'),
        valid => '0'
    );
    constant INVALID_CTRL_RESPONSE : axi_ctrl_read_response_t := (
        ra_ready => '1',
        rd_data => (others => (others => 'U')),
        rd_valid => '0',
        rd_ok => 'U',
        rd_ok_valid => '0'
    );

    signal axi_address : axi_address_t;
    signal axi_address_ready : std_ulogic;
    signal axi_data : axi_read_data_t;
    signal axi_data_ready : std_ulogic := '0';
    signal ctrl_request : axi_ctrl_read_request_t;
    signal ctrl_response : axi_ctrl_read_response_t := INVALID_CTRL_RESPONSE;

    signal axi_tick_count : natural := 0;
    signal ctrl_tick_count : natural := 0;

    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

begin
    axi_clk <= not axi_clk after AXI_PERIOD;
    ctrl_clk <= not ctrl_clk after CTRL_PERIOD;

    axi_read : entity work.gddr6_axi_read generic map (
        FIFO_BITS => FIFO_BITS
    ) port map (
        axi_clk_i => axi_clk,
        axi_address_i => axi_address,
        axi_address_ready_o => axi_address_ready,
        axi_data_o => axi_data,
        axi_data_ready_i => axi_data_ready,

        ctrl_clk_i => ctrl_clk,
        ctrl_request_o => ctrl_request,
        ctrl_response_i => ctrl_response
    );


    -- Send address request
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
        axi_address <= INVALID_AXI_ADDRESS;

        clk_wait(2);

--         -- A single invalid burst
--         send(X"F", X"FF00_0000", X"00", "111");
--         -- Two longer invalid bursts back to back
--         send(X"F", X"FF00_0000", X"02", "111");
--         send(X"F", X"FF00_0000", X"01", "111");
--         wait;

--         -- A simple burst: two SG bursts, four AXI beats
--         send(X"1", X"0000_0100", X"03", "110");
--         wait;

        -- A simple burst: one SG burst, two AXI beats
        send(X"1", X"0000_0100", X"01", "110");
        wait;

        -- A single cycle of data from the start of an SG burst
        send(X"1", X"0000_0100", X"00", "110");
        send(X"1", X"0000_0100", X"00", "110");
        wait;

        -- A single cycle of data from the end of an SG burst, so skip the first
        -- half burst each time
        send(X"2", X"0000_0240", X"00", "110");
        send(X"2", X"0000_0240", X"00", "110");
        wait;

        send(X"3", X"1234_0020", X"02", "101");

        -- A single SG burst with narrow response, should generate four AXI
        -- responses
        send(X"3", X"1234_0000", X"03", "101");
        -- Same with two SG bursts
        send(X"3", X"1234_0000", X"07", "101");
        wait;


        -- Start with an invalid burst, should return four cycles of invalid
        -- data
        send(X"F", X"FF00_0000", X"03", "111");
        -- Next a single entire SG burst, should return two cycles of data
        send(X"0", X"0000_0000", X"01", "110");
        -- A more complex rendering of a single SG burst, should return the same
        -- data four times
        send(X"3", X"0003_0000", X"03", "101");
        send(X"A", X"1234_5678", X"05", "110");
        send(X"B", X"9ABC_DEF0", X"02", "110");

        wait;
    end process;

    -- Log addresses received by CTRL
    process (ctrl_clk) begin
        if rising_edge(ctrl_clk) then
            ctrl_tick_count <= ctrl_tick_count + 1;

            if ctrl_request.ra_valid and ctrl_response.ra_ready then
                write("@ctrl " & to_string(ctrl_tick_count) &
                    " RA " & to_hstring(ctrl_request.ra_address));
            end if;
        end if;
    end process;


--     axi_data_ready <= '1';

    -- Log data returned to AXI
    process (axi_clk) begin
        if rising_edge(axi_clk) then
            axi_tick_count <= axi_tick_count + 1;

           -- Delayed response
--             axi_data_ready <= axi_data.valid and not axi_data_ready;
            axi_data_ready <= axi_data.valid;

            if axi_data.valid and axi_data_ready then
                write("@axi " & to_string(axi_tick_count) &
                    " R " & to_hstring(axi_data.id) & " " &
                    to_hstring(axi_data.resp) & " " &
                    choose(axi_data.last = '1', "L", "-") & " " &
                    to_hstring(axi_data.data));
            end if;
        end if;
    end process;

    -- Generate data in response to address request
    process
        procedure clk_wait(count : natural := 1) is
        begin
            clk_wait(ctrl_clk, count);
        end;

        variable data_counter : natural := 0;

        procedure generate_data is
        begin
            data_counter := data_counter + 1;

            ctrl_response.rd_valid <= '1';
            ctrl_response.rd_data <=
                (others => to_std_ulogic_vector_u(data_counter, 128));
        end;

    begin
        loop
            -- Invalid data while we're waiting for a request
            ctrl_response.rd_valid <= '0';
            ctrl_response.rd_ok_valid <= '0';
            ctrl_response.rd_ok <= 'U';
            ctrl_response.rd_data <= (others => (others => 'U'));

            -- Wait for a new request
            while not (ctrl_request.ra_valid and ctrl_response.ra_ready) loop
                clk_wait;
            end loop;

            -- Generate two bursts of data
            ctrl_response.ra_ready <= '0';
            generate_data;
            clk_wait;
            generate_data;

            -- Generate OK response at same time as data (not realistic, but a
            -- bit easier than the correct phasing of OK)
            ctrl_response.rd_ok_valid <= '1';
            ctrl_response.rd_ok <= '1';

            -- Ack
            ctrl_response.ra_ready <= '1';
            clk_wait;
        end loop;
    end process;
end;
