-- Simple command decoding

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

use work.gddr6_ctrl_command_defs.all;

entity decode_commands is
    port (
        clk_i : in std_ulogic;
        ca_command_i : in ca_command_t
    );
end;

architecture arch of decode_commands is
    signal tick_count : natural := 0;
    signal mask_counter : natural := 0;

    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

    function decode_command(command : ca_command_t) return string is
        variable ca : vector_array(0 to 1)(9 downto 0);
        variable decode_bits : std_ulogic_vector(5 downto 0);
    begin
        ca := command.ca;
        decode_bits := ca(0)(9 downto 8) & ca(1)(9 downto 6);
        case? decode_bits is
            when "1111--" | "1110--" | "1011--" =>
                if ca(0)(7 downto 0) & ca(1)(7 downto 0) /= X"FFFF" then
                    return "NOP " & to_hstring(
                        ca(1)(7 downto 0) & ca(0)(7 downto 0));
                else
                    return "NOP";
                end if;
            when "1010--" =>
                return "MRS " &
                    to_hstring(ca(0)(7 downto 4)) & " " &
                    to_hstring(ca(1)(7 downto 0) & ca(0)(3 downto 0));
            when "0-----" =>
                return "ACT " &
                    to_hstring(ca(0)(7 downto 4)) & " " &
                    to_hstring(ca(1) & ca(0)(3 downto 0));
            when "110100" =>
                return "RD" & choose(ca(1)(4) = '1', "A", "") & " " &
                    to_hstring(ca(0)(7 downto 4)) & " " &
                    to_hstring(ca(1)(2 downto 0) & ca(0)(3 downto 0));
            when "110000" =>
                return "WOM" & choose(ca(1)(4) = '1', "A", "") & " " &
                    to_hstring(ca(0)(7 downto 4)) & " " &
                    to_hstring(ca(1)(2 downto 0) & ca(0)(3 downto 0));
            when "110001" =>
                return "WSM" & choose(ca(1)(4) = '1', "A", "") & " " &
                    to_hstring(ca(0)(7 downto 4)) & " " &
                    to_hstring(ca(1)(2 downto 0) & ca(0)(3 downto 0));
            when "110010" =>
                return "WDM" & choose(ca(1)(4) = '1', "A", "") & " " &
                    to_hstring(ca(0)(7 downto 4)) & " " &
                    to_hstring(ca(1)(2 downto 0) & ca(0)(3 downto 0));
            when "1000--" =>
                return "PRE" & choose(ca(1)(4) = '1',
                    "ab", "pb " & to_hstring(ca(0)(7 downto 4)));
            when "1001--" =>
                return "REF" & choose(ca(1)(4) = '1',
                    "ab", "p2b " & to_hstring(ca(0)(6 downto 4)));
            when others =>
                return "Other: " &
                    to_hstring(ca(0)) & " " & to_hstring(ca(1));
        end case?;
    end;

    function decode_mask(command : ca_command_t) return string is
        variable ca : vector_array(0 to 1)(9 downto 0);
    begin
        ca := command.ca;

        if ca(0)(9 downto 8) & ca(1)(9 downto 8) = "1111" then
            return "Mask: " & to_hstring(ca(1)(7 downto 0) & ca(0)(7 downto 0));
        else
            return "Invalid mask: " &
                to_hstring(ca(0)) & " "& to_hstring(ca(1));
        end if;
    end;

    function is_simple_nop(command : ca_command_t) return boolean is
        variable ca : vector_array(0 to 1)(9 downto 0);
        variable decode_bits : std_ulogic_vector(3 downto 0);
    begin
        ca := command.ca;
        decode_bits := ca(0)(9 downto 8) & ca(1)(9 downto 8);
        case? decode_bits is
            when "1111" | "1110" | "1011" =>
                return ca(0)(7 downto 0) & ca(1)(7 downto 0) = X"FFFF";
            when others =>
                return false;
        end case?;
    end;

    function extra_commands(command : ca_command_t) return natural is
        variable ca : vector_array(0 to 1)(9 downto 0);
        variable decode_bits : std_ulogic_vector(5 downto 0);
    begin
        ca := command.ca;
        decode_bits := ca(0)(9 downto 8) & ca(1)(9 downto 6);
        case? decode_bits is
            when "110010" => return 1;
            when "110001" => return 2;
            when others => return 0;
        end case?;
    end;

begin
    -- Decode CA commands and print
    process (clk_i)
        type string_ptr_t is access string;
        variable decode : string_ptr_t;
        variable simple_nop : boolean;

    begin
        if rising_edge(clk_i) then
            if mask_counter > 0 then
                decode := new string'(decode_mask(ca_command_i));
                mask_counter <= mask_counter - 1;
                simple_nop := false;
            else
                decode := new string'(decode_command(ca_command_i));
                mask_counter <= extra_commands(ca_command_i);
                simple_nop := is_simple_nop(ca_command_i);
            end if;
            if not simple_nop then
                write("@ " & to_string(tick_count) & " " & decode.all);
            end if;
            tick_count <= tick_count + 1;
        end if;
    end process;
end;