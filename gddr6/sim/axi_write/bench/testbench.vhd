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


    signal axi_address : axi_address_t := INVALID_AXI_ADDRESS;
    signal axi_address_ready : std_ulogic;
    signal axi_data : axi_write_data_t := INVALID_AXI_DATA;
    signal axi_data_ready : std_ulogic;
    signal axi_response : axi_write_response_t;
    signal axi_response_ready : std_ulogic := '0';
    signal ctrl_request : axi_ctrl_write_request_t;

    -- Because we assemble the response in multiple processes we need to
    -- aggregate the response structure separately
    signal ctrl_response_wa_ready : std_ulogic := '0';
    signal ctrl_response_wd_advance : std_ulogic;
    signal ctrl_response_wd_ready : std_ulogic := '0';
    signal ctrl_response_wr_ok : std_ulogic;
    signal ctrl_response_wr_ok_valid : std_ulogic := '0';
    signal ctrl_response : axi_ctrl_write_response_t;

    signal axi_tick_count : natural := 0;
    signal ctrl_tick_count : natural := 0;

    constant DATA_DELAY : natural := 10;
    constant RESPONSE_DELAY : natural := DATA_DELAY + 10;
    signal write_valid : std_ulogic;
    signal write_phase : std_ulogic;
    signal write_advance : std_ulogic;
    signal delay_write_valid : std_ulogic := '0';
    signal delay_write_phase : std_ulogic;
    signal delay_write_advance : std_ulogic;
    signal delay_write_mask : std_ulogic_vector(127 downto 0);

begin
    axi_clk <= not axi_clk after AXI_PERIOD;
    ctrl_clk <= not ctrl_clk after CTRL_PERIOD;

    axi_write : entity work.gddr6_axi_write generic map (
        DATA_FIFO_BITS => FIFO_BITS,
        COMMAND_FIFO_BITS => FIFO_BITS
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
            size : unsigned(2 downto 0) := "110") is
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
            write("@" & to_string(axi_tick_count) & " WA " &
                to_hstring(id) & " " & to_hstring(addr) & " " &
                to_hstring(len) & " " & to_hstring(size));
            axi_address <= INVALID_AXI_ADDRESS;
        end;

    begin
        axi_address <= INVALID_AXI_ADDRESS;

        clk_wait(5);

        send(X"0", X"0001_0080", X"03", "101");
        send(X"0", X"0001_0000", X"00");
        send(X"0", X"0001_0040", X"00");

        -- A simple burst: one SG burst, two AXI beats
        send(X"1", X"0000_0000", X"01");
        clk_wait(10);
        -- Similar, but repeated 3 times on SG side
        send(X"2", X"2000_0080", X"01");
        -- An invalid burst, no SG writes generated
        send(X"3", X"0000_0100", X"03", "111");

        -- Now a more complex sequence of narrow writes
        send(X"4", X"0000_0230", X"06", "100");

        wait;
    end process;


    -- Send data
    process
        procedure clk_wait(count : natural := 1) is
        begin
            clk_wait(axi_clk, count);
        end;


        -- Two kinds of marked up data
        type DATA_TYPE is (DATA_BYTES, DATA_CHANNELS);

        variable data_counter : natural := 0;


        impure function generate_data(
            mask : std_ulogic_vector(63 downto 0);
            dtype : DATA_TYPE) return std_ulogic_vector
        is
            impure function generate_slice(
                index : natural) return std_ulogic_vector
            is
                variable result : std_ulogic_vector(127 downto 0);
            begin
                result := (
                    7 downto 0 => to_std_ulogic_vector_u(index, 8),
                    31 downto 8 => to_std_ulogic_vector_u(data_counter, 24),
                    others => '0'
                );
                return result;
            end;

            variable result : std_ulogic_vector(511 downto 0);
        begin
            case dtype is
                when DATA_BYTES =>
                    for byte in 0 to 63 loop
                        result(8*byte + 7 downto 8*byte) :=
                            to_std_ulogic_vector_u(
                                byte + 64 * (data_counter mod 4), 8);
                    end loop;
                when DATA_CHANNELS =>
                    result :=
                        generate_slice(3) & generate_slice(2) &
                        generate_slice(1) & generate_slice(0);
            end case;

            -- Mask out any bytes we're not writing
            for byte in 0 to 63 loop
                if not mask(byte) then
                    result(8*byte + 7 downto 8*byte) := (others => '-');
                end if;
            end loop;
            return result;
        end;

        procedure send_data(
            mask : std_ulogic_vector(63 downto 0);
            last : std_ulogic := '0'; dtype : DATA_TYPE := DATA_CHANNELS)
        is
            variable data_out : std_ulogic_vector(511 downto 0);
        begin
            data_out := generate_data(mask, dtype);
            data_counter := data_counter + 1;

            axi_data <= (
                data => data_out,
                strb => mask,
                last => last,
                valid => '1'
            );
            loop
                clk_wait;
                exit when axi_data_ready;
            end loop;
            write("@" & to_string(axi_tick_count) & " W " &
                to_hstring(mask) & " " & choose(last = '1', "L", "-") & " " &
                to_hstring(data_out));
            axi_data <= INVALID_AXI_DATA;
        end;

        procedure send_data_burst(
            count : natural;
            mask : std_ulogic_vector(63 downto 0) := (others => '1');
            dtype : DATA_TYPE := DATA_CHANNELS) is
        begin
            for i in 1 to count loop
                send_data(mask, to_std_ulogic(i = count), dtype);
            end loop;
        end;

    begin
        axi_data <= INVALID_AXI_DATA;
        clk_wait(5);

        send_data(X"0000_0000_FFFF_FFFF");
        send_data(X"FFFF_FFFF_0000_0000");
        send_data(X"0000_0000_FFFF_FFFF");
        send_data(X"FFFF_FFFF_0000_0000", '1');

        send_data_burst(1, dtype => DATA_BYTES);
        send_data_burst(1, dtype => DATA_BYTES);

        -- Simple burst: one SG, two AXI
        send_data_burst(2);
        -- Similar
        send_data_burst(2);
        send_data_burst(4);

        -- Sequential bursts
        send_data(X"FFFF_0000_0000_0000");
        send_data(X"0000_0000_0000_FFFF");
        send_data(X"0000_0000_FFFF_0000");
        send_data(X"0000_FFFF_0000_0000");
        send_data(X"FFFF_0000_0000_0000");
        send_data(X"0000_0000_0000_FFFF");
        send_data(X"0000_0000_FFFF_0000", '1');

        wait;
    end process;


    -- Report write response
    axi_response_ready <= '1';
    process (axi_clk)
        function to_resp_string(resp : std_ulogic_vector) return string is
        begin
            case resp is
                when "00" => return "OK";
                when "10" => return "SLVERR";
                when others => return "???";
            end case;
        end;

    begin
        if rising_edge(axi_clk) then
            axi_tick_count <= axi_tick_count + 1;

--             axi_response_ready <= axi_response.valid and not axi_response_ready;
            if axi_response.valid and axi_response_ready then
                write("@" & to_string(axi_tick_count) & " B " &
                    to_hstring(axi_response.id) & " " &
                    to_resp_string(axi_response.resp));
            end if;
        end if;
    end process;


    -- Accept SG requests and repeat where appropriate (encoded in bits 21:20 of
    -- the address)
    process
        procedure clk_wait(count : natural := 1) is
        begin
            clk_wait(ctrl_clk, count);
        end;

    begin
        ctrl_response_wa_ready <= '0';
        write_valid <= '0';

        loop
            exit when ctrl_request.wa_valid;
            clk_wait;
        end loop;
        write("%" & to_string(ctrl_tick_count) & " SG addr " &
            to_hstring(ctrl_request.wa_address) & " " &
            to_hstring(ctrl_request.wa_byte_mask));

        -- Generate repeats and acknowledge when done
        for i in to_integer(ctrl_request.wa_address(22 downto 21)) downto 0 loop
            write_valid <= '1';
            write_phase <= '0';
            write_advance <= to_std_ulogic(i = 0);
            clk_wait;
            write_phase <= '1';
            if i = 0 then
                write_advance <= '1';
                ctrl_response_wa_ready <= '1';
            end if;
            clk_wait;
        end loop;
        -- Without this wait we don't necessarily see the *next* wa_valid value!
        wait for 1 ps;
    end process;



    -- Delay line for SG to data
    data_delay_inst : entity work.fixed_delay generic map (
        WIDTH => 131,
        DELAY => DATA_DELAY
    ) port map (
        clk_i => ctrl_clk,
        data_i(0) => write_valid,
        data_i(1) => write_phase,
        data_i(2) => write_advance,
        data_i(130 downto 3) => ctrl_request.wa_byte_mask,
        data_o(0) => delay_write_valid,
        data_o(1) => delay_write_phase,
        data_o(2) => delay_write_advance,
        data_o(130 downto 3) => delay_write_mask
    );

    delay_response : entity work.fixed_delay generic map (
        WIDTH => 2,
        DELAY => RESPONSE_DELAY
    ) port map (
        clk_i => ctrl_clk,
        data_i(0) => write_valid and write_phase and write_advance,
        data_i(1) => not ctrl_request.wa_address(24),
        data_o(0) => ctrl_response_wr_ok_valid,
        data_o(1) => ctrl_response_wr_ok
    );


--     -- Data request generator
--     process
--         procedure clk_wait(count : natural := 1) is
--         begin
--             clk_wait(ctrl_clk, count);
--         end;
-- 
--         procedure show_data is
--         begin
--         end;
-- 
--         variable replay_count : integer;
-- 
--     begin
--         ctrl_response_wd_ready <= '0';
--         loop
--             clk_wait;
--             exit when data_delay_valid;
--         end loop;
-- 
--         for i in 0 to to_integer(data_replay_count) loop
--             ctrl_response_wd_ready <= '1';
--             clk_wait;
--         end loop;
--     end process;
-- 

    ctrl_response_wd_ready <= delay_write_valid;
    ctrl_response_wd_advance <= delay_write_advance;
    process (ctrl_clk)
        procedure report_write_data(data : vector_array(0 to 3)(127 downto 0))
        is
        begin
            write("%" & to_string(ctrl_tick_count) & " SG data " &
                to_hstring(data(3)) & " " & to_hstring(data(2)) & " " &
                to_hstring(data(1)) & " " & to_hstring(data(0)));
        end;

    begin
        if rising_edge(ctrl_clk) then
            ctrl_tick_count <= ctrl_tick_count + 1;

            -- Report data as we see it
            if ctrl_response.wd_ready then
                report_write_data(ctrl_request.wd_data);
            end if;

--             -- Acknowledge and report request.  Enforce one tick between
--             -- requests
--             ctrl_response_wa_ready <=
--                 ctrl_request.wa_valid and not ctrl_response_wa_ready;
--             if ctrl_request.wa_valid and ctrl_response_wa_ready then
--                 write("%" & to_string(ctrl_tick_count) & " SG " &
--                     to_hstring(ctrl_request.wa_address) & " " &
--                     to_hstring(ctrl_request.wa_byte_mask));
--             end if;
        end if;
    end process;

    ctrl_response <= (
        wa_ready  => ctrl_response_wa_ready,
        wd_advance => ctrl_response_wd_advance,
        wd_ready => ctrl_response_wd_ready,
        wr_ok => ctrl_response_wr_ok,
        wr_ok_valid => ctrl_response_wr_ok_valid
    );
end;
