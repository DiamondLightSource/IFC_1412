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

    constant DATA_DELAY : natural := 10;
    constant STATUS_DELAY : natural := 5;
    signal data_address_delay : unsigned(24 downto 0);
    signal data_address_delay_valid : std_ulogic;

    signal axi_ack_delay : natural := 0;
    signal ctrl_ack_delay : natural := 0;

    signal axi_tick_count : natural := 0;
    signal ctrl_tick_count : natural := 0;

    -- FIFO for RA used to manage validation of returned data
    type axi_address_array_t is array(natural range <>) of axi_address_t;
--     constant ADDRESS_FIFO_COUNT : natural := 1024;
    constant ADDRESS_FIFO_COUNT : natural := 128;
    signal address_fifo_in_ptr : natural := 0;
    signal address_fifo_out_ptr : natural := 0;
    signal address_fifo : axi_address_array_t(0 to ADDRESS_FIFO_COUNT-1);

    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

    function to_resp_string(resp : std_ulogic_vector) return string is
    begin
        case resp is
            when "00" => return "OK";
            when "10" => return "SLVERR";
            when others => return "???";
        end case;
    end;

    -- Fields used to pack address information into data
    subtype FIELD_RANGE is natural range 127 downto 120;
    subtype COUNTER_RANGE is natural range 95 downto 64;
    subtype ADDRESS_RANGE is natural range 32 downto 8;

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

        procedure expect(address : axi_address_t)
        is
            variable in_ptr : natural;
        begin
            in_ptr := (address_fifo_in_ptr + 1) mod ADDRESS_FIFO_COUNT;
            assert in_ptr /= address_fifo_out_ptr
                report "address fifo full"
                severity failure;
            address_fifo(address_fifo_in_ptr) <= address;
            address_fifo_in_ptr <= in_ptr;
        end;

        procedure send(
            id : std_logic_vector(3 downto 0);
            addr : unsigned(31 downto 0);
            len : unsigned(7 downto 0);
            size : unsigned(2 downto 0))
        is
            variable address : axi_address_t;
        begin
            address := (
                id => id,
                addr => addr,
                len => len,
                size => size,
                burst => "01",
                valid => '1'
            );
            expect(address);
            axi_address <= address;
            loop
                clk_wait;
                exit when axi_address_ready;
            end loop;
            write("@" & to_string(axi_tick_count) & " RA " &
                to_hstring(id) & " " &
                to_hstring(addr) & " " & to_hstring(len) & " " &
                to_hstring(size));
            axi_address <= INVALID_AXI_ADDRESS;
        end;

    begin
        axi_address <= INVALID_AXI_ADDRESS;

        clk_wait(2);

        -- Sequential misaligned bursts
        send(X"4", X"1000_0040", X"00", "110");
        send(X"4", X"1000_00C0", X"00", "110");
        send(X"4", X"1000_0140", X"00", "110");
        send(X"4", X"1000_01C0", X"00", "110");
        send(X"4", X"1000_0240", X"00", "110");
        send(X"3", X"0000_1000", X"01", "111");

        -- Four bursts, two short ones followed by two slightly longer ones
        send(X"3", X"0000_1000", X"01", "110");
        send(X"E", X"0001_EF12", X"0E", "110");
        send(X"3", X"0000_1080", X"01", "110");
        send(X"3", X"0000_1100", X"03", "110");
        send(X"3", X"0000_1200", X"03", "110");

        -- Working through misaligned bursts
        send(X"4", X"1000_0040", X"00", "110");
        send(X"4", X"1000_0040", X"01", "110");
        send(X"4", X"1000_0040", X"02", "110");
        send(X"4", X"1000_0040", X"03", "110");
        send(X"4", X"1000_0080", X"02", "110");

        -- Top bit of address set, will report error
        send(X"3", X"8000_1200", X"03", "110");

        -- A simple but misaligned narrow burst
        send(X"0", X"0000_0010", X"04", "100");     -- 3 repeats then 2

        -- An AXI burst straddling two SG bursts followed by an aligned burst
        send(X"1", X"0000_1040", X"01", "110");
        send(X"1", X"0000_1100", X"01", "110");

        -- An invalid address, triggers counter wraparound, but is processed
        send(X"E", X"0001_EF12", X"0E", "110");

        -- A single AXI burst (so generates a skip) followed by an invalid burst
        send(X"1", X"0002_0000", X"00", "110");
        send(X"1", X"0000_0000", X"00", "110");
        send(X"1", X"0000_0000", X"00", "110");
        send(X"1", X"2BCD_0000", X"00", "110");
        send(X"2", X"0003_0000", X"00", "111");

        -- Some long bursts
        send(X"E", X"0000_0000", X"FF", "110");

        -- Similar, but the skip is at the start of the burst
        send(X"3", X"0004_0040", X"00", "110");
        send(X"4", X"0005_0000", X"00", "111");

        -- A full SG burst followed by an invalid burst
        send(X"3", X"0006_0000", X"01", "110");
        send(X"4", X"0007_0000", X"00", "111");

        -- Two longer invalid bursts back to back
        send(X"3", X"7F00_0000", X"02", "111");
        send(X"4", X"7F00_0000", X"01", "111");

        -- A simple burst: two SG bursts, four AXI beats
        send(X"1", X"0000_0100", X"03", "110");

        -- A simple burst: one SG burst, two AXI beats
        send(X"1", X"0000_0100", X"01", "110");

        -- A single cycle of data from the start of an SG burst
        send(X"1", X"0000_0100", X"00", "110");
        send(X"1", X"0000_0100", X"00", "110");

        -- A single cycle of data from the end of an SG burst, so skip the first
        -- half burst each time
        send(X"2", X"0000_0240", X"00", "110");
        send(X"2", X"0000_0240", X"00", "110");

        send(X"3", X"1234_0020", X"02", "101");

        -- A single SG burst with narrow response, should generate four AXI
        -- responses
        send(X"3", X"1234_0000", X"03", "101");
        -- Same with two SG bursts
        send(X"3", X"1234_0000", X"07", "101");


        -- Start with an invalid burst, should return four cycles of invalid
        -- data
        send(X"F", X"7F00_0000", X"03", "111");
        -- Next a single entire SG burst, should return two cycles of data
        send(X"0", X"0000_0000", X"01", "110");
        -- A more complex rendering of a single SG burst, should return the same
        -- data four times
        send(X"3", X"0003_0000", X"03", "101");
        send(X"A", X"1234_5678", X"05", "110");
        send(X"B", X"1ABC_DEF0", X"02", "110");

        -- End the test with some very long tests.
        -- First the longest possible burst we can process
        send(X"E", X"0000_0000", X"3F", "110");
        -- Finally a the longest possible 256 entry burst
        send(X"E", X"0000_0000", X"FF", "110");

        wait;
    end process;


    -- -------------------------------------------------------------------------
    -- SG read emulation

    -- Delay lines for SG requests so we can delay responses accordingly
    data_delay_inst : entity work.fixed_delay generic map (
        WIDTH => 26,
        DELAY => DATA_DELAY
    ) port map (
        clk_i => ctrl_clk,
        data_i(24 downto 0) => std_ulogic_vector(ctrl_request.ra_address),
        data_i(25) => ctrl_request.ra_valid and ctrl_response.ra_ready,
        unsigned(data_o(24 downto 0)) => data_address_delay,
        data_o(25) => data_address_delay_valid
    );

    -- Use top bit of address to generate ok: top bit set means not ok
    status_delay_inst : entity work.fixed_delay generic map (
        WIDTH => 2,
        DELAY => STATUS_DELAY
    ) port map (
        clk_i => ctrl_clk,
        data_i(0) => data_address_delay_valid,
        data_i(1) => not data_address_delay(24),
        data_o(0) => ctrl_response.rd_ok_valid,
        data_o(1) => ctrl_response.rd_ok
    );


    -- Emulate SG engine
    process (ctrl_clk)
        variable ack_counter : natural := 0;
        variable data_phase : natural range 0 to 1;
        variable data_address : unsigned(24 downto 0);
        variable data_counter : natural := 0;

        procedure generate_data(phase : natural) is
        begin
            for field in 0 to 3 loop
                ctrl_response.rd_data(field) <= (
                    FIELD_RANGE =>
                        to_std_ulogic_vector_u(field, 4) &
                        to_std_ulogic_vector_u(phase, 4),
                    COUNTER_RANGE =>
                        to_std_ulogic_vector_u(data_counter / 2, 32),
                    ADDRESS_RANGE =>
                        std_ulogic_vector(data_address),
                    others => '0');
            end loop;
            ctrl_response.rd_valid <= '1';

            data_counter := data_counter + 1;
        end;

    begin
        if rising_edge(ctrl_clk) then
            ctrl_tick_count <= ctrl_tick_count + 1;

            -- Ensure we don't accept more than one SG request every two ticks
            -- and implement ctrl_ack_delay
            if ack_counter > 0 then
                ack_counter := ack_counter - 1;
            elsif ctrl_request.ra_valid then
                ack_counter := ctrl_ack_delay + 1;
            end if;
            ctrl_response.ra_ready <= to_std_ulogic(ack_counter = 0);

            -- Log received and acknowledged request
            if ctrl_request.ra_valid and ctrl_response.ra_ready then
                write("%" & to_string(ctrl_tick_count) & " SG " &
                    to_hstring(ctrl_request.ra_address));
            end if;

            -- Generate two ticks of data as appropriate
            if data_phase = 0 and data_address_delay_valid = '1' then
                data_address := data_address_delay;
                generate_data(0);
                data_phase := 1;
            elsif data_phase = 1 then
                assert not data_address_delay_valid severity failure;
                data_phase := 0;
                generate_data(1);
            else
                ctrl_response.rd_valid <= '0';
            end if;
        end if;
    end process;


    -- -------------------------------------------------------------------------
    -- AXI data validation

    process (axi_clk)
    begin
        if rising_edge(axi_clk) then
            axi_tick_count <= axi_tick_count + 1;
        end if;
    end process;


    -- Validate received data against originating request
    process
        procedure clk_wait(count : natural := 1) is
        begin
            clk_wait(axi_clk, count);
        end;


        -- Returns next request from internal queue
        procedure get_address(variable address : out axi_address_t) is
        begin
            if address_fifo_in_ptr = address_fifo_out_ptr then
                address := (
                    id => (others => 'U'),
                    addr => (others => 'U'),
                    len => (others => 'U'),
                    size => (others => 'U'),
                    burst => (others => 'U'),
                    valid => '0'
                );
                clk_wait;
            else
                address := address_fifo(address_fifo_out_ptr);
                address_fifo_out_ptr <=
                    (address_fifo_out_ptr + 1) mod ADDRESS_FIFO_COUNT;
            end if;
        end;


        -- Checks whether the burst request is expected to return valid data,
        -- this affects whether we validate the returned data
        function valid_request(request : axi_address_t) return boolean
        is
            variable last_offset : unsigned(14 downto 0);
        begin
            -- A burst is valid so long as it is not too large for our bus and
            -- it doesn't cross a 4K boundary.  However, our engine is a bit
            -- more permissive and merely checks that the request length is
            -- compatible with the associated SG burst count
            last_offset :=
                resize(request.addr(6 downto 0), 15) +
                shift_left(resize(request.len, 15), to_integer(request.size));
            return
                request.burst = "01"  and
                request.size <= 6  and
                (last_offset and 15X"7000") = 0;
        end;


        -- Wait for data with configurable acknowledgement delay
        procedure get_data(
            ack_delay : natural;
            variable data : out axi_read_data_t) is
        begin
            axi_data_ready <= to_std_ulogic(ack_delay = 0);

            loop
                clk_wait;
                exit when axi_data.valid;
            end loop;
            data := axi_data;

            -- Doing the delay correctly is surprisingly awkward
            if ack_delay > 0 then
                clk_wait(ack_delay - 1);
                axi_data_ready <= '1';
                clk_wait;
            end if;

            axi_data_ready <= '0';
        end;


        type digest_t is record
            phase : std_ulogic;
            address : unsigned(24 downto 0);
            counter : natural;
        end record;

        -- Returns information encoded in the returned data and checks that it
        -- is consistent across the entire data word.
        function digest_data(data : axi_read_data_t) return digest_t
        is
            variable digest : digest_t;
            variable bits : std_ulogic_vector(127 downto 0);
            variable field : std_ulogic_vector(7 downto 0);
            variable address : unsigned(24 downto 0);
            variable counter : natural;
            variable expected_field : std_ulogic_vector(7 downto 0);
        begin
            for i in 0 to 3 loop
                bits := data.data(128*i + 127 downto 128*i);
                field := bits(FIELD_RANGE);
                address := unsigned(bits(ADDRESS_RANGE));
                counter := to_integer(unsigned(bits(COUNTER_RANGE)));

                expected_field := (
                    0 => to_std_ulogic(i mod 2 = 1),
                    4 => to_std_ulogic(i / 2 = 1 ),
                    5 => field(5),
                    others => '0');
                assert field = expected_field severity failure;
                if i = 0 then
                    digest := (
                        phase => field(5),
                        address => address,
                        counter => counter);
                else
                    assert field(5) = digest.phase severity failure;
                    assert address = digest.address severity failure;
                    assert counter = digest.counter severity failure;
                end if;
            end loop;
            return digest;
        end;


        variable data_counter : natural := 0;

        -- Checks address and sequence number of data against expected values
        procedure check_data(
            count : natural; request : axi_address_t;
            digest : digest_t; last : std_ulogic)
        is
            -- Compute the expected SG address.  This is a little involved: only
            -- the intra-page part is advanced, and the increment depends on the
            -- underlying request size.
            function compute_address(n : natural) return unsigned is
            begin
                return
                    request.addr(31 downto 12) &
                    resize(shift_right(
                        request.addr(11 downto 0) +
                            n * shift_left(12X"1", to_integer(request.size)),
                        6),
                    6);
            end;

            variable address : unsigned(25 downto 0);
            variable next_address : unsigned(25 downto 0);

        begin
            address := compute_address(count);
            assert address = (digest.address & digest.phase) severity failure;
            assert data_counter = digest.counter severity failure;

            next_address := compute_address(count + 1);
            if last = '1' or next_address(1) /= address(1) then
                data_counter := data_counter + 1;
            end if;
        end;


        variable request : axi_address_t;
        variable data : axi_read_data_t;
        variable digest : digest_t;

        variable last_tick : natural := 0;
        variable interval : natural;

    begin
        get_address(request);
        if request.valid then
            write("@" & to_string(axi_tick_count) & " request = (" &
                to_hstring(request.id) & ", " &
                to_hstring(request.addr) & ", " &
                to_hstring(request.len) & ", " &
                to_hstring(request.size) & ")");

            -- Work through the expected burst response sequence
            for count in 0 to to_integer(request.len) loop
                get_data(axi_ack_delay, data);
                interval := axi_tick_count - last_tick;
                if interval > 1 and last_tick > 0 then
                    write(" delta = +" & to_string(interval - 1));
                end if;
                last_tick := axi_tick_count;

                -- Check the AXI tags match
                assert request.id = data.id severity failure;
                -- Check the last entry in the burst is correctly marked
                assert (count = to_integer(request.len)) = (data.last = '1')
                    severity failure;

                if valid_request(request) then
                    -- For a successful request the data should be valid
                    digest := digest_data(data);
                    write("@" & to_string(axi_tick_count) & " R " &
                        to_hstring(data.id) & " " &
                        to_resp_string(data.resp) & " " &
                        choose(data.last = '1', "L", "-") & " " &
                        to_hstring(digest.address) & "." &
                        to_string(digest.phase) & " " &
                        to_string(digest.counter));
                    -- Check that the special error from addr(31) is present
                    assert
                        (request.addr(31) = '0' and data.resp = "00")  or
                        (request.addr(31) = '1' and data.resp = "10")
                        severity failure;
                    check_data(count, request, digest, data.last);
                else
                    -- For bad requests we need to ignore the data
                    write("@" & to_string(axi_tick_count) & " R " &
                        to_hstring(data.id) & " " &
                        to_resp_string(data.resp) & " " &
                        choose(data.last = '1', "L", "-"));
                    assert data.resp = "10" severity failure;
                end if;
            end loop;
        end if;
    end process;
end;
