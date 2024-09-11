-- AXI write master for simulation

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_axi_defs.all;

entity sim_axi_master is
    port (
        clk_i : in std_ulogic;

        -- WA
        axi_wa_o : out axi_address_t;
        axi_wa_ready_i : in std_ulogic;
        -- W
        axi_w_o : out axi_write_data_t;
        axi_w_ready_i : in std_ulogic;
        -- B
        axi_b_i : in axi_write_response_t;
        axi_b_ready_o : out std_ulogic;

        -- RA
        axi_ra_o : out axi_address_t;
        axi_ra_ready_i : in std_ulogic;
        -- R
        axi_r_i : in axi_read_data_t;
        axi_r_ready_o : out std_ulogic
    );
end;

architecture arch of sim_axi_master is
    signal tick_count : natural := 0;

    procedure clk_wait(count : natural := 1) is
    begin
        for i in 1 to count loop
            wait until rising_edge(clk_i);
        end loop;
    end;

    procedure write(prefix : string; message : string) is
        variable linebuffer : line;
    begin
        write(linebuffer,
            "@" & to_string(tick_count) & " " & prefix & " " & message);
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

begin
    axi_ra_o <= IDLE_AXI_ADDRESS;
    axi_r_ready_o <= '0';

    -- We are always read to report B
    axi_b_ready_o <= '1';

    process (clk_i) begin
        if rising_edge(clk_i) then
            tick_count <= tick_count + 1;

            -- Report write completion
            if axi_b_i.valid then
                write("B",
                    to_hstring(axi_b_i.id) & " " &
                    to_resp_string(axi_b_i.resp));
            end if;
        end if;
    end process;


    -- Sent write address requests
    process
        procedure send(
            id : std_logic_vector(3 downto 0);
            addr : unsigned(31 downto 0);
            len : unsigned(7 downto 0);
            size : unsigned(2 downto 0) := "110") is
        begin
            axi_wa_o <= (
                id => id,
                addr => addr,
                len => len,
                size => size,
                burst => "01",
                valid => '1'
            );
            loop
                clk_wait;
                exit when axi_wa_ready_i;
            end loop;
            write("WA",
                to_hstring(id) & " " & to_hstring(addr) & " " &
                to_hstring(len) & " " & to_hstring(size));
            axi_wa_o <= IDLE_AXI_ADDRESS;
        end;

    begin
        axi_wa_o <= IDLE_AXI_ADDRESS;

        clk_wait(5);

        -- A simple burst: one SG burst, two AXI beats
        send(X"1", X"0000_0000", X"01");
        -- Similar, but with partial writes
        send(X"2", X"0000_0080", X"01");
        send(X"2", X"0000_0100", X"01");
        send(X"2", X"0000_0180", X"00");
--         send(X"2", X"0000_0100", X"01");

--         clk_wait(10);
--         -- Similar, but repeated 3 times on SG side
--         send(X"2", X"2000_0080", X"01", "110");
--         -- An invalid burst, no SG writes generated
--         send(X"3", X"0000_0100", X"03", "111");
-- 
--         -- Now a more complex sequence of narrow writes
--         send(X"4", X"0000_0230", X"06", "100");

        wait;
    end process;


    -- Send data
    process
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

            axi_w_o <= (
                data => data_out,
                strb => mask,
                last => last,
                valid => '1'
            );
            loop
                clk_wait;
                exit when axi_w_ready_i;
            end loop;
            write("W",
                to_hstring(mask) & " " & choose(last = '1', "L", "-") & " " &
                to_hstring(data_out));
            axi_w_o <= IDLE_AXI_WRITE_DATA;
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
        axi_w_o <= IDLE_AXI_WRITE_DATA;
        clk_wait(5);

        -- Simple burst: one SG, two AXI
        send_data_burst(2, dtype => DATA_BYTES);
        -- Burst with non-trival mask
--         send_data_burst(2, X"0000_0000_FFFF_FFFF");
        send_data(X"0000_0000_FFFF_FFFF");
        send_data(X"0000_0000_0000_0000", '1');
        send_data(X"0000_0000_0000_FFFF");
        send_data(X"0000_0000_0000_0000", '1');
        send_data(X"0000_0000_0000_FFFE", '1');

--         -- Similar
--         send_data_burst(2);
--         send_data_burst(4);
-- 
--         -- Sequential bursts
--         send_data(X"FFFF_0000_0000_0000");
--         send_data(X"0000_0000_0000_FFFF");
--         send_data(X"0000_0000_FFFF_0000");
--         send_data(X"0000_FFFF_0000_0000");
--         send_data(X"FFFF_0000_0000_0000");
--         send_data(X"0000_0000_0000_FFFF");
--         send_data(X"0000_0000_FFFF_0000", '1');

        wait;
    end process;


end;
