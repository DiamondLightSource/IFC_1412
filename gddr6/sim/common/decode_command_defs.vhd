-- Functions and procedures for helping CA command decode and logging

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

use work.gddr6_ctrl_command_defs.all;

package decode_command_defs is
--     -- Returns string describing a single command
--     function decode_command(ca : ca_command_t) return string;
--     -- Returns string describing a WDM/WSM mask
--     function decode_mask(ca : ca_command_t) return string;

    procedure decode_command(
        variable mask_counter : inout natural;
        prefix : string; ca : ca_command_t; report_nop : boolean := false);
end;

package body decode_command_defs is
    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

    function decode_command(
        ca : ca_command_t; assert_unexpected : boolean := true) return string
    is
        variable decode_bits : std_ulogic_vector(5 downto 0);
    begin
        decode_bits := ca.ca(0)(9 downto 8) & ca.ca(1)(9 downto 6);
        case? decode_bits is
            when "1111--" | "1110--" | "1011--" =>
                if ca.ca(0)(7 downto 0) & ca.ca(1)(7 downto 0) /= X"FFFF" then
                    assert not assert_unexpected
                        report "NOP " & to_hstring(
                            ca.ca(1)(7 downto 0) & ca.ca(0)(7 downto 0))
                        severity failure;
                    return "NOP " & to_hstring(
                        ca.ca(1)(7 downto 0) & ca.ca(0)(7 downto 0));
                else
                    return "NOP";
                end if;
            when "1010--" =>
                return "MRS " &
                    to_hstring(ca.ca(0)(7 downto 4)) & " " &
                    to_hstring(ca.ca(1)(7 downto 0) & ca.ca(0)(3 downto 0));
            when "0-----" =>
                return "ACT " &
                    to_hstring(ca.ca(0)(7 downto 4)) & " " &
                    to_hstring(ca.ca(1) & ca.ca(0)(3 downto 0));
            when "110100" =>
                return "RD" & choose(ca.ca(1)(4) = '1', "A", "") & " " &
                    to_hstring(ca.ca(0)(7 downto 4)) & " " &
                    to_hstring(ca.ca(1)(2 downto 0) & ca.ca(0)(3 downto 0));
            when "110000" =>
                return "WOM" & choose(ca.ca(1)(4) = '1', "A", "") & " " &
                    to_hstring(ca.ca(0)(7 downto 4)) & " " &
                    to_hstring(
                        ca.ca(1)(2 downto 0) & ca.ca(0)(3 downto 0)) & " " &
                    to_string(reverse(ca.ca3));
            when "110001" =>
                return "WSM" & choose(ca.ca(1)(4) = '1', "A", "") & " " &
                    to_hstring(ca.ca(0)(7 downto 4)) & " " &
                    to_hstring(
                        ca.ca(1)(2 downto 0) & ca.ca(0)(3 downto 0)) & " " &
                    to_string(reverse(ca.ca3));
            when "110010" =>
                return "WDM" & choose(ca.ca(1)(4) = '1', "A", "") & " " &
                    to_hstring(ca.ca(0)(7 downto 4)) & " " &
                    to_hstring(
                        ca.ca(1)(2 downto 0) & ca.ca(0)(3 downto 0)) & " " &
                    to_string(reverse(ca.ca3));
            when "1000--" =>
                return "PRE" & choose(ca.ca(1)(4) = '1',
                    "ab", "pb " & to_hstring(ca.ca(0)(7 downto 4)));
            when "1001--" =>
                return "REF" & choose(ca.ca(1)(4) = '1',
                    "ab", "p2b " & to_hstring(ca.ca(0)(6 downto 4)));
            when others =>
                assert not assert_unexpected
                    report "Other: " &
                        to_hstring(ca.ca(0)) & " " & to_hstring(ca.ca(1))
                    severity failure;
                return "Other: " &
                    to_hstring(ca.ca(0)) & " " & to_hstring(ca.ca(1));
        end case?;
    end;

    function decode_mask(ca : ca_command_t) return string is
    begin
        if ca.ca(0)(9 downto 8) & ca.ca(1)(9 downto 8) = "1111" then
            return "Mask: " &
                to_hstring(ca.ca(1)(7 downto 0) & ca.ca(0)(7 downto 0));
        else
            return "Malformed mask: " &
                to_hstring(ca.ca(0)) & " "& to_hstring(ca.ca(1));
        end if;
    end;

    function is_simple_nop(ca : ca_command_t) return boolean is
        variable decode_bits : std_ulogic_vector(3 downto 0);
    begin
        decode_bits := ca.ca(0)(9 downto 8) & ca.ca(1)(9 downto 8);
        case? decode_bits is
            when "1111" | "1110" | "1011" =>
                return ca.ca(0)(7 downto 0) & ca.ca(1)(7 downto 0) = X"FFFF";
            when others =>
                return false;
        end case?;
    end;

    -- Returns number of mask commands expected to follow
    function mask_count(ca : ca_command_t) return natural is
        variable decode_bits : std_ulogic_vector(5 downto 0);
    begin
        decode_bits := ca.ca(0)(9 downto 8) & ca.ca(1)(9 downto 6);
        case? decode_bits is
            when "110010" => return 1;
            when "110001" => return 2;
            when others => return 0;
        end case?;
    end;


    procedure decode_command(
        variable mask_counter : inout natural;
        prefix : string; ca : ca_command_t; report_nop : boolean := false) is
    begin
        if mask_counter > 0 then
            write(prefix & decode_mask(ca));
            mask_counter := mask_counter - 1;
        elsif report_nop or not is_simple_nop(ca) then
            write(prefix & decode_command(ca));
            mask_counter := mask_count(ca);
        end if;
    end;
end;
