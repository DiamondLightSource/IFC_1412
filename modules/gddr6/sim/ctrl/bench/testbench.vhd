library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

use work.gddr6_ctrl_defs.all;
use work.gddr6_defs.all;

entity testbench is
end testbench;


architecture arch of testbench is
    signal clk : std_ulogic := '0';

    procedure clk_wait(count : natural := 1) is
    begin
        for i in 1 to count loop
            wait until rising_edge(clk);
        end loop;
    end;

    signal tick_count : natural;

    -- Setting the refresh interval to 100 rather than 475 ticks results in a
    -- much more challenging test and can expose subtle issues in the design.
    constant SHORT_REFRESH_COUNT : natural := 150;
    constant LONG_REFRESH_COUNT : natural := 10;

    signal ctrl_setup : ctrl_setup_t;
    signal temperature : sg_temperature_t;
    signal axi_read_request   : axi_ctrl_read_request_t;
    signal axi_read_response  : axi_ctrl_read_response_t;
    signal axi_write_request  : axi_ctrl_write_request_t;
    signal axi_write_response : axi_ctrl_write_response_t;
    signal phy_ca : phy_ca_t;
    signal phy_dq_out : phy_dq_out_t;
    signal phy_dq_in : phy_dq_in_t;

    signal verbose : boolean := false;
    signal read_priority : boolean := false;
    signal write_priority : boolean := false;

    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

    impure function write_efficiency(
        start_tick : natural; count : natural) return string
    is
        variable efficiency : real;
    begin
        efficiency := 2.0 * real(count) / real(tick_count - start_tick);
        return to_string(100.0 * efficiency, 1) & "%";
    end;

    procedure wait_for_tick(target : natural) is
    begin
        while tick_count < target loop
            clk_wait;
        end loop;
    end;

    procedure wait_for(signal input : in boolean; target : boolean := true) is
    begin
        while input /= target loop
            clk_wait;
        end loop;
    end;

begin
    clk <= not clk after 2 ns;

    ctrl : entity work.gddr6_ctrl generic map (
--         SHORT_REFRESH_COUNT => SHORT_REFRESH_COUNT,
        LONG_REFRESH_COUNT => LONG_REFRESH_COUNT
    ) port map (
        clk_i => clk,
        ctrl_setup_i => ctrl_setup,
        temperature_o => temperature,
        axi_read_request_i => axi_read_request,
        axi_read_response_o => axi_read_response,
        axi_write_request_i => axi_write_request,
        axi_write_response_o => axi_write_response,
        phy_ca_o => phy_ca,
        phy_dq_o => phy_dq_out,
        phy_dq_i => phy_dq_in
    );

    phy : entity work.sim_phy port map (
        clk_i => clk,
        phy_ca_i => phy_ca,
        phy_dq_i => phy_dq_out,
        phy_dq_o => phy_dq_in
    );


    process begin
        ctrl_setup <= (
            enable_axi => '1',
            enable_refresh => '1',
            priority_mode => '0',
            priority_direction => '1'
        );

        loop
            clk_wait;
            if read_priority and not write_priority then
                ctrl_setup.priority_mode <= '1';
                ctrl_setup.priority_direction <= '0';
            elsif not read_priority and write_priority then
                ctrl_setup.priority_mode <= '1';
                ctrl_setup.priority_direction <= '1';
            else
                ctrl_setup.priority_mode <= '0';
            end if;
        end loop;

        wait;
    end process;


    -- Generate write requests
    process
        -- Some simple byte mask patterns
        constant NOP : std_ulogic_vector(31 downto 0) := X"0000_0000";
        constant WOM : std_ulogic_vector(31 downto 0) := X"FFFF_FFFF";
        -- Corresponding WDM mask is: D81B
        constant WDM : std_ulogic_vector(31 downto 0) := X"F3C0_03CF";
        -- Corresponding WSM mask is: 46EC (even), 1416 (odd)
        constant WSM : std_ulogic_vector(31 downto 0) := X"1234_5678";

        variable write_count : natural := 0;
        variable start_tick : natural;

        procedure do_write(
            address : natural; count : natural := 1;
            mask : std_ulogic_vector := WOM & WOM & WOM & WOM;
            lookahead : natural := 2**25) is
        begin
            axi_write_request.wa_byte_mask <= mask;
            axi_write_request.wa_valid <= '1';
            if lookahead < 2**25 then
                axi_write_request.wal_address <= to_unsigned(lookahead, 25);
                axi_write_request.wal_valid <= '1';
            else
                axi_write_request.wal_valid <= '0';
            end if;

            -- Emit the burst, count down to end of burst for lookahead
            for i in 0 to count-1 loop
                axi_write_request.wa_address <= to_unsigned(address + i, 25);
                axi_write_request.wal_count <= to_unsigned(count - i - 1, 5);
                loop
                    clk_wait;
                    exit when axi_write_response.wa_ready;
                end loop;
                write_count := write_count + 1;
            end loop;

            -- Between requests mark address and lookahead as invalid
            axi_write_request.wa_address <= (others => 'U');
            axi_write_request.wa_byte_mask <= (others => 'U');
            axi_write_request.wa_valid <= '0';
            axi_write_request.wal_address <= (others => 'U');
            axi_write_request.wal_count <= (others => 'U');
            axi_write_request.wal_valid <= '0';
        end;

        procedure start_test(description : string) is
        begin
            start_tick := tick_count;
            write_count := 0;
            write(
                "@ " & to_string(tick_count) &
                " Starting " & description & " test");
        end;

        procedure end_test(description : string := "") is
        begin
            write(
                "@ " & to_string(tick_count) & " " & description &
                " done: " & write_efficiency(start_tick, write_count));
        end;

    begin
        axi_write_request.wa_valid <= '0';
        axi_write_request.wal_valid <= '0';

        -- Start with a single write in isolation
        clk_wait(5);
        do_write(0);
        clk_wait(20);

        -- Start with a write efficiency test.  The result depends on the value
        -- of SHORT_REFRESH_COUNT according to the following table:
        --  475 : 99.1%     200 : 92.5%     150 : 85.7%     100 : 68.7%
        -- Note that below 100 refresh tends to run out of time!
        start_test("write only timing test");
        write_priority <= true;
        for n in 0 to 128 loop
            do_write(32 * n, 32, lookahead => 32 * (n + 1));
        end loop;
        write_priority <= false;
        end_test("write only");

        -- Wait out the read test
        wait_for(read_priority, false);
        wait_for(read_priority);
        wait_for(read_priority, false);

        -- Now do the burst test with overlapping reads and writes
        start_test("shared write timing test");
        for n in 0 to 64 loop
            do_write(32 * n, 32, lookahead => 32 * (n + 1));
        end loop;
        end_test("shared write");

        -- A couple of standalone writes
        do_write(999, mask => WSM & NOP & NOP & NOP);
        do_write(999);
        do_write(999, mask => WSM & WDM & WSM & WOM);
        clk_wait(10);
        do_write(999);
        clk_wait(10);

        start_test("scattered and large writes");
        for n in 0 to 512 loop
            do_write(n, mask => WSM & WSM & WOM & WOM);
            do_write(n + 512);
            do_write(n + 1024);
        end loop;
        end_test("large writes");

        start_test("conflicting banks");
        for n in 0 to 64 loop
            do_write(n, 32, lookahead => n + 512);
            do_write(n + 512, 32, lookahead => n + 2048);
            do_write(n + 2048, 32, lookahead => 32 * (n + 1));
        end loop;
        end_test("conflicting");

        start_test("multiple banks");
        for n in 0 to 64 loop
            do_write(n, 32, lookahead => n + 512);
            do_write(n + 512, 32, lookahead => n + 1024);
            do_write(n + 1024, 32, lookahead => 32 * (n + 1));
        end loop;
        end_test("multiple");

        write("All writes complete");

        wait;
    end process;

    -- Generate read requests
    process
        variable read_count : natural := 0;
        variable start_tick : natural;

        procedure do_read(
            address : natural; count : natural := 1;
            lookahead : natural := 2**25) is
        begin
            axi_read_request.ra_valid <= '1';
            if lookahead < 2**25 then
                axi_read_request.ral_address <= to_unsigned(lookahead, 25);
                axi_read_request.ral_valid <= '1';
            else
                axi_read_request.ral_valid <= '0';
            end if;

            -- Emit the burst, count down to end of burst for lookahead
            for i in 0 to count-1 loop
                axi_read_request.ra_address <= to_unsigned(address + i, 25);
                axi_read_request.ral_count <= to_unsigned(count - i - 1, 5);
                loop
                    clk_wait;
                    exit when axi_read_response.ra_ready;
                end loop;
                read_count := read_count + 1;
            end loop;

            -- Between requests mark address and lookahead as invalid
            axi_read_request.ra_address <= (others => 'U');
            axi_read_request.ra_valid <= '0';
            axi_read_request.ral_address <= (others => 'U');
            axi_read_request.ral_count <= (others => 'U');
            axi_read_request.ral_valid <= '0';
        end;

        procedure start_test(description : string) is
        begin
            start_tick := tick_count;
            read_count := 0;
            write(
                "@ " & to_string(tick_count) &
                " Starting " & description & " test");
        end;

        procedure end_test(description : string := "") is
        begin
            write(
                "@ " & to_string(tick_count) & " " & description &
                " done: " & write_efficiency(start_tick, read_count));
        end;

    begin
        axi_read_request.ra_valid <= '0';
        axi_read_request.ral_valid <= '0';

        clk_wait(5);

        -- Wait for write test to complete
        wait_for(write_priority, false);

        start_test("read only timing test");
        read_priority <= true;
        for n in 0 to 128 loop
            do_read(32 * n, 32, lookahead => 32 * (n + 1));
        end loop;
        read_priority <= false;
        end_test("read only");

        start_test("shared read timing test");
        for n in 0 to 64 loop
            do_read(32 * n, 32, lookahead => 32 * (n + 1));
        end loop;
        end_test("shared read");


        start_tick := tick_count;
        for n in 0 to 512 loop
            do_read(n);
            do_read(n + 128);
            do_read(n + 1024);
        end loop;

        write("All reads complete");

        wait;
    end process;


    -- Generate AXI write data
    process
        variable data_counter : natural := 0;
        variable phase : std_ulogic := '0';
    begin
        loop
            -- Generate a 16-bit counter in each word of output
            for ch in 0 to 3 loop
                for word in 0 to 7 loop
                    axi_write_request.wd_data(ch)(16*word+15 downto 16*word) <=
                        to_std_ulogic_vector_u(
                            32 * data_counter + 8 * ch + word, 16);
                end loop;
            end loop;

            loop
                clk_wait;
                exit when axi_write_response.wd_ready;
            end loop;

            -- Advance data counter as appropriate
            if not phase or axi_write_response.wd_advance then
                data_counter := data_counter + 1;
            else
                data_counter := data_counter - 1;
            end if;
            phase := not phase;
        end loop;
    end process;


    decode : entity work.decode_commands generic map (
        ASSERT_UNEXPECTED => true
    ) port map (
        clk_i => clk,
        ca_command_i => ( ca => phy_ca.ca, ca3 => phy_ca.ca3 ),
        report_i => verbose,
        tick_count_o => tick_count
    );
end;
