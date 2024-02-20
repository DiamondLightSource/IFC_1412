library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

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

    signal data_in : std_ulogic_vector(7 downto 0);
    signal extra_in : std_ulogic;
    signal valid_in : std_ulogic;
    signal ready_out : std_ulogic;
    signal ok_in : std_ulogic;
    signal data_out : std_ulogic_vector(7 downto 0);
    signal extra_out : std_ulogic;
    signal valid_out : std_ulogic;
    signal ready_in : std_ulogic := '1';
    signal ok_out : std_ulogic;
    signal test_out : std_ulogic_vector(7 downto 0);
    signal test_valid_out : std_ulogic;
    signal test_extra_out : std_ulogic;
    signal test_ok_in : std_ulogic;

--     signal data_in2 : std_ulogic_vector(7 downto 0);
--     signal extra_in2 : std_ulogic;
--     signal valid_in2 : std_ulogic;
--     signal ready_out2 : std_ulogic;
--     signal ok_in2 : std_ulogic;
--     signal data_out2 : std_ulogic_vector(7 downto 0);
--     signal extra_out2 : std_ulogic;
--     signal valid_out2 : std_ulogic;
--     signal ready_in2 : std_ulogic;
--     signal ok_out2 : std_ulogic;
--     signal test_out2 : std_ulogic_vector(7 downto 0);
--     signal test_valid_out2 : std_ulogic;
--     signal test_ok_in2 : std_ulogic;

    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

    signal message_count : natural := 0;
    signal tick_count : natural := 0;

begin
    clk <= not clk after 2 ns;

    engine : entity work.engine port map (
        clk_i => clk,

        data_i => data_in,
        extra_i => extra_in,
        valid_i => valid_in,
        ready_o => ready_out,
        ok_i => ok_in,

        data_o => data_out,
        extra_o => extra_out,
        valid_o => valid_out,
        ready_i => ready_in,
        ok_o => ok_out,

        test_o => test_out,
        test_valid_o => test_valid_out,
        test_extra_o => test_extra_out,
        test_ok_i => test_ok_in
    );

--     engine2 : entity work.engine port map (
--         clk_i => clk,
-- 
--         data_i => data_in2,
--         extra_i => extra_in2,
--         valid_i => valid_in2,
--         ready_o => ready_out2,
--         ok_i => ok_in2,
-- 
--         data_o => data_out2,
--         extra_o => extra_out2,
--         valid_o => valid_out2,
--         ready_i => ready_in2,
--         ok_o => ok_out2,
-- 
--         test_o => test_out2,
--         test_valid_o => test_valid_out2,
--         test_ok_i => test_ok_in2
--     );

    -- Test bench sending requests
    process
        procedure send(extra : std_ulogic := '0') is
        begin
            data_in <= to_std_ulogic_vector_u(message_count, 8);
            message_count <= message_count + 1;
            extra_in <= extra;
            valid_in <= '1';
            loop
                clk_wait;
                exit when ready_out;
            end loop;
            valid_in <= '0';
        end;

    begin
        valid_in <= '0';
--         ready_in <= '1';
        ok_in <= '1';

        clk_wait(3);
        send;
        send('1');
        send('1');
        send;
        send;

        wait;
    end process;

    -- Test response
    process begin
        test_ok_in <= '0';
        while test_valid_out /= '1' loop
            clk_wait;
        end loop;
        clk_wait;
        write("@ " & to_string(tick_count) &
            " test " & to_hstring(test_out) & " " & to_string(test_extra_out));
        test_ok_in <= '1';
        clk_wait;
    end process;
--     test_ok_in <= transport test_valid_out after 10 ns;

    -- Watch output
    process (clk) begin
        if rising_edge(clk) then
            tick_count <= tick_count + 1;
            if ok_out and valid_out and ready_in then
                write("@ " & to_string(tick_count) & " command " &
                    to_hstring(data_out) & " " & to_string(extra_out));
            end if;

--             -- Alternate acceptance of output
--             ready_in <= not ready_in;
        end if;
    end process;
end;
