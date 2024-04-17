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

    signal write_count : natural := 0;
    signal read_count : natural := 0;

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
        SHORT_REFRESH_COUNT => SHORT_REFRESH_COUNT,
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
--         priority_mode => '1',       -- Select preferred direction
        priority_mode => '0',       -- Switch directions regularly
        priority_direction => '1'   -- Writes take priority
    );


    -- Generate write requests
    process
        procedure do_write(address : natural) is
        begin
            axi_request.wa_address <= to_unsigned(address, 25);
            axi_request.wa_byte_mask <= (others => '1');
            axi_request.wa_valid <= '1';
            loop
                clk_wait;
                exit when axi_response.wa_ready;
            end loop;
            axi_request.wa_address <= (others => 'U');
            axi_request.wa_byte_mask <= (others => 'U');
            axi_request.wa_valid <= '0';
            write_count <= write_count + 1;
        end;

        variable start_tick : natural;

    begin
        axi_request.wa_valid <= '0';
        axi_request.wal_valid <= '0';

        clk_wait(5);

        start_tick := tick_count;
        for n in 0 to 512 loop
            do_write(n);
            do_write(n + 512);
--             do_write(n + 1024);
--             do_write(n + 2048);
        end loop;

        write("All writes complete: " &
            write_efficiency(start_tick, write_count));

        wait;
    end process;

    -- Generate read requests
    process
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
            read_count <= read_count + 1;
        end;

        variable start_tick : natural;

    begin
        axi_request.ra_valid <= '0';
        axi_request.ral_valid <= '0';

        clk_wait(5);

        start_tick := tick_count;
        for n in 0 to 512 loop
            do_read(n);
            do_read(n + 1024);
        end loop;

        write("All reads complete: " &
            write_efficiency(start_tick, read_count));

        wait;
    end process;


    decode : entity work.decode_commands port map (
        clk_i => clk,
        ca_command_i => ( ca => phy_ca.ca, ca3 => phy_ca.ca3 ),
        tick_count_o => tick_count
    );
end;
