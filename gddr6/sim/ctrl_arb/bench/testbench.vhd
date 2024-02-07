library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

use work.gddr6_ctrl_commands.all;
use work.gddr6_ctrl_core_defs.all;

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

    signal bank_active_in : std_ulogic_vector(0 to 15);
    signal bank_active_out : std_ulogic_vector(0 to 15);
    signal bank_allow_read : std_ulogic_vector(0 to 15);
    signal bank_allow_write : std_ulogic_vector(0 to 15);
    signal bank_row : unsigned_array(0 to 15)(13 downto 0);

    signal bank_action_read : std_ulogic_vector(0 to 15);
    signal bank_action_write : std_ulogic_vector(0 to 15);
    signal bank_action_auto_precharge : std_ulogic_vector(0 to 15);

    signal direction : sg_direction_t;
    signal direction_idle : std_ulogic;
    signal idle_priority : sg_direction_t;

    signal activate_bank : unsigned(3 downto 0);
    signal activate_row : unsigned(13 downto 0);
    signal activate_valid : std_ulogic;
    signal activate_ready : std_ulogic;

    signal write_request : core_request_t;
    signal write_request_extra : std_ulogic;
    signal write_request_ready : std_ulogic;

    signal read_request : core_request_t;
    signal read_request_ready : std_ulogic;

    signal bank_command : ca_command_t;
    signal bank_command_valid : std_ulogic;
    signal bank_command_ready : std_ulogic;

    signal ca_command : ca_command_t;


    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

begin
    clk <= not clk after 2 ns;

    arb : entity work.gddr6_ctrl_arb port map (
        clk_i => clk,

        bank_active_i => bank_active_in,
        bank_active_o => bank_active_out,
        bank_row_i => bank_row,
        bank_allow_read_i => bank_allow_read,
        bank_allow_write_i => bank_allow_write,

        bank_action_read_o => bank_action_read,
        bank_action_write_o => bank_action_write,
        bank_action_auto_precharge_o => bank_action_auto_precharge,

        direction_i => direction,
        direction_idle_i => direction_idle,
        idle_priority_i => idle_priority,

        activate_bank_o => activate_bank,
        activate_row_o => activate_row,
        activate_valid_o => activate_valid,
        activate_ready_i => activate_ready,

        write_request_i => write_request,
        write_request_extra_i => write_request_extra,
        write_request_ready_o => write_request_ready,

        read_request_i => read_request,
        read_request_ready_o => read_request_ready,

        bank_command_i => bank_command,
        bank_command_valid_i => bank_command_valid,
        bank_command_ready_o => bank_command_ready,

        ca_command_o => ca_command
    );


    process
        variable bank : natural range 0 to 15;

    begin
        -- Initial state for all banks: inactive
        bank_active_in <= (others => '0');
        bank_allow_read <= (others => '0');
        bank_allow_write <= (others => '0');
        bank_row <= (others => (others => 'U'));
        direction <= DIRECTION_WRITE;
        direction_idle <= '1';
        idle_priority <= DIRECTION_READ;

        bank_command_valid <= '0';

        loop
            activate_ready <= '0';
            clk_wait;
            if activate_valid then
                bank := to_integer(activate_bank);
--                 clk_wait;

                -- Request an activate command
                bank_command <= SG_ACT(activate_bank, activate_row);
                bank_command_valid <= '1';
                loop
                    clk_wait;
                    exit when bank_command_ready;
                end loop;
                bank_command_valid <= '0';

                -- Now mark this bank as active
                bank_active_in(bank) <= '1';
                bank_row(bank) <= activate_row;
                activate_ready <= '1';
                bank_allow_read(bank) <= '1';
                clk_wait;
                activate_ready <= '0';
                clk_wait(3);
                bank_allow_write(bank) <= '1';
                clk_wait;
            end if;
        end loop;

        wait;
    end process;

    process
        procedure write(
            bank : unsigned; row : unsigned; column : unsigned;
            precharge : std_ulogic; extra : std_ulogic) is
        begin
            write_request <= (
                bank => bank, row => row,
                command => SG_WOM(bank, column), precharge => precharge,
                valid => '1');
            write_request_extra <= extra;
            loop
                clk_wait;
                exit when write_request_ready;
            end loop;
            write_request.valid <= '0';
        end;

        procedure write_extra(mask : std_ulogic_vector; extra : std_ulogic) is
        begin
            write_request.command <= SG_write_mask(mask);
            write_request_extra <= extra;
            clk_wait;
        end;

    begin
        read_request <= invalid_core_request;
        write_request <= invalid_core_request;
        write_request_extra <= '0';

        clk_wait(5);
        write(X"3", 14X"1234", 7X"23", '0', '0');
        write(X"3", 14X"1234", 7X"24", '0', '1');
        write_extra(16X"ABCD", '0');
        write(X"3", 14X"1234", 7X"25", '0', '0');
        write(X"3", 14X"0765", 7X"25", '0', '0');

        wait;
    end process;


    -- Decode CA commands and print
    process (clk)
        variable decode_bits : std_ulogic_vector(5 downto 0);
        variable ca : vector_array(0 to 1)(9 downto 0);
        variable mask_counter : natural := 0;
    begin
        if rising_edge(clk) then
            ca := ca_command.ca;
            if mask_counter > 0 then
                assert ca(0)(9 downto 8) & ca(1)(9 downto 8) = "1111"
                    report "Invalid mask"
                    severity failure;
                write("Mask: " &
                    to_hstring(ca(1)(7 downto 0) & ca(0)(7 downto 0)));
                mask_counter := mask_counter - 1;
            else
                decode_bits := ca(0)(9 downto 8) & ca(1)(9 downto 6);
                case? decode_bits is
                    when "1111--" | "1110--" | "1011--" =>
                        if ca(0)(7 downto 0) & ca(1)(7 downto 0) /= X"FFFF" then
                            write("NOP " & to_hstring(
                                ca(1)(7 downto 0) & ca(0)(7 downto 0)));
                        end if;
                    when "1010--" =>
                        write("MRS");
                    when "0-----" =>
                        write("ACT " &
                            to_hstring(ca(0)(7 downto 4)) & " " &
                            to_hstring(ca(1) & ca(0)(3 downto 0)));
                    when "110100" =>
                        write("RD" & choose(ca(1)(4) = '1', "A", "") & " " &
                            to_hstring(ca(0)(7 downto 4)) & " " &
                            to_hstring(ca(1)(2 downto 0) & ca(0)(3 downto 0)));
                    when "110000" =>
                        write("WOM" & choose(ca(1)(4) = '1', "A", "") & " " &
                            to_hstring(ca(0)(7 downto 4)) & " " &
                            to_hstring(ca(1)(2 downto 0) & ca(0)(3 downto 0)));
                    when "110001" =>
                        write("WSM" & choose(ca(1)(4) = '1', "A", "") & " " &
                            to_hstring(ca(0)(7 downto 4)) & " " &
                            to_hstring(ca(1)(2 downto 0) & ca(0)(3 downto 0)));
                        mask_counter := 2;
                    when "110010" =>
                        write("WDM" & choose(ca(1)(4) = '1', "A", "") & " " &
                            to_hstring(ca(0)(7 downto 4)) & " " &
                            to_hstring(ca(1)(2 downto 0) & ca(0)(3 downto 0)));
                        mask_counter := 1;
                    when "1000--" =>
                        write("PRE" & choose(ca(1)(4) = '1',
                            "ab", "pb " & to_hstring(ca(0)(7 downto 4))));
                    when "1001--" =>
                        write("REF" & choose(ca(1)(4) = '1',
                            "ab", "p2b " & to_hstring(ca(0)(6 downto 4))));
                    when others =>
                        write("Other: " &
                            to_hstring(ca(0)) & " " & to_hstring(ca(1)));
                end case?;
            end if;
        end if;
    end process;
end;
