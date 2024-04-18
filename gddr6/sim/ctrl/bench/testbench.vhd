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

    procedure clk_wait(count : natural := 1) is
    begin
        for i in 1 to count loop
            wait until rising_edge(clk);
        end loop;
    end;

    signal tick_count : natural;

    constant SHORT_REFRESH_COUNT : natural := 200;
    constant LONG_REFRESH_COUNT : natural := 10;

    signal ctrl_setup : ctrl_setup_t;
    signal ctrl_status : ctrl_status_t;
    signal axi_request : axi_request_t;
    signal axi_response : axi_response_t;
    signal phy_ca : phy_ca_t;
    signal phy_dq_out : phy_dq_out_t;
    signal phy_dq_in : phy_dq_in_t;

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

begin
    clk <= not clk after 2 ns;

    ctrl : entity work.gddr6_ctrl generic map (
--         SHORT_REFRESH_COUNT => SHORT_REFRESH_COUNT,
        LONG_REFRESH_COUNT => LONG_REFRESH_COUNT
    ) port map (
        clk_i => clk,
        ctrl_setup_i => ctrl_setup,
        ctrl_status_o => ctrl_status,
        axi_request_i => axi_request,
        axi_response_o => axi_response,
        phy_ca_o => phy_ca,
        phy_dq_o => phy_dq_out,
        phy_dq_i => phy_dq_in
    );

    ctrl_setup <= (
        enable_refresh => '1',
        priority_mode => '1',       -- Select preferred direction
--         priority_mode => '0',       -- Switch directions regularly
        priority_direction => '1'   -- Writes take priority
    );


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
            axi_request.wa_byte_mask <= mask;
            axi_request.wa_valid <= '1';
            if lookahead < 2**25 then
                axi_request.wal_address <= to_unsigned(lookahead, 25);
                axi_request.wal_valid <= '1';
            else
                axi_request.wal_valid <= '0';
            end if;

            -- Emit the burst, count down to end of burst for lookahead
            for i in 0 to count-1 loop
                axi_request.wa_address <= to_unsigned(address + i, 25);
                axi_request.wal_count <= to_unsigned(count - i - 1, 5);
                loop
                    clk_wait;
                    exit when axi_response.wa_ready;
                end loop;
                write_count := write_count + 1;
            end loop;

            -- Between requests mark address and lookahead as invalid
            axi_request.wa_address <= (others => 'U');
            axi_request.wa_byte_mask <= (others => 'U');
            axi_request.wa_valid <= '0';
            axi_request.wal_address <= (others => 'U');
            axi_request.wal_count <= (others => 'U');
            axi_request.wal_valid <= '0';
        end;

    begin
        axi_request.wa_valid <= '0';
        axi_request.wal_valid <= '0';

        clk_wait(2);

        -- A couple of standalone writes
        do_write(999);
        clk_wait(10);
        do_write(999);
        clk_wait(10);
wait;

        start_tick := tick_count;
        for n in 0 to 128 loop
            do_write(32 * n, 32, lookahead => 32 * (n + 1));
        end loop;
        write("Bursts done: " & write_efficiency(start_tick, write_count));
        wait;

        start_tick := tick_count;
        for n in 0 to 512 loop
            do_write(n, mask => WSM & WSM & WOM & WOM);
--             do_write(n + 512);
--             do_write(n + 1024);
--             do_write(n + 2048);
        end loop;

        write("All writes complete: " &
            write_efficiency(start_tick, write_count));

        wait;
    end process;

    -- Generate read requests
    process
        variable read_count : natural := 0;
        variable start_tick : natural;


        procedure do_read(address : natural) is
        begin
            axi_request.ra_address <= to_unsigned(address, 25);
            axi_request.ra_valid <= '1';
            loop
                clk_wait;
                exit when axi_response.ra_ready;
            end loop;
            axi_request.ra_address <= (others => 'U');
            axi_request.ra_valid <= '0';
            read_count := read_count + 1;
        end;

    begin
        axi_request.ra_valid <= '0';
        axi_request.ral_valid <= '0';

        clk_wait(5);

        -- A couple of standalone reads
        do_read(999);
        clk_wait(10);
        do_read(999);
        clk_wait(10);

wait;

        start_tick := tick_count;
        for n in 0 to 512 loop
            do_read(n);
            do_read(n + 1024);
        end loop;

        write("All reads complete: " &
            write_efficiency(start_tick, read_count));

        wait;
    end process;


    -- Generate write data
    process
        variable data_counter : natural := 0;
        variable phase : std_ulogic := '0';

    begin
        loop
            -- Generate a 16-bit counter in each word of output
            for ch in 0 to 3 loop
                for word in 0 to 7 loop
                    axi_request.wd_data(ch)(16*word+15 downto 16*word) <=
                        to_std_ulogic_vector_u(
                            32 * data_counter + 8 * ch + word, 16);
                end loop;
            end loop;

            loop
                clk_wait;
                exit when axi_response.wd_ready;
            end loop;

            if not phase or axi_response.wd_advance then
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
        tick_count_o => tick_count
    );
end;
