-- Decodes stream of CA commands and prints the result

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

use work.gddr6_ctrl_command_defs.all;

entity decode_commands is
    generic (
        REPORT_NOP : boolean := false;
        -- Set this to only look at commands with valid_i set and ignore
        -- otherwise broken write masked commands
        ONLY_VALID : boolean := false;
        -- Set to fail on unexected command
        ASSERT_UNEXPECTED : boolean := false
    );
    port (
        clk_i : in std_ulogic;
        valid_i : in std_ulogic := '1';
        ca_command_i : in ca_command_t;
        report_i : in boolean := true;
        tick_count_o : out natural
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

    function decode_command(
        ca : vector_array; ce : std_ulogic_vector) return string
    is
        variable decode_bits : std_ulogic_vector(5 downto 0);
    begin
        decode_bits := ca(0)(9 downto 8) & ca(1)(9 downto 6);
        case? decode_bits is
            when "1111--" | "1110--" | "1011--" =>
                if ca(0)(7 downto 0) & ca(1)(7 downto 0) /= X"FFFF" then
                    assert not ASSERT_UNEXPECTED
                        report "NOP " & to_hstring(
                            ca(1)(7 downto 0) & ca(0)(7 downto 0))
                        severity failure;
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
                    to_hstring(ca(1)(2 downto 0) & ca(0)(3 downto 0)) & " " &
                    to_string(reverse(ce));
            when "110001" =>
                return "WSM" & choose(ca(1)(4) = '1', "A", "") & " " &
                    to_hstring(ca(0)(7 downto 4)) & " " &
                    to_hstring(ca(1)(2 downto 0) & ca(0)(3 downto 0)) & " " &
                    to_string(reverse(ce));
            when "110010" =>
                return "WDM" & choose(ca(1)(4) = '1', "A", "") & " " &
                    to_hstring(ca(0)(7 downto 4)) & " " &
                    to_hstring(ca(1)(2 downto 0) & ca(0)(3 downto 0)) & " " &
                    to_string(reverse(ce));
            when "1000--" =>
                return "PRE" & choose(ca(1)(4) = '1',
                    "ab", "pb " & to_hstring(ca(0)(7 downto 4)));
            when "1001--" =>
                return "REF" & choose(ca(1)(4) = '1',
                    "ab", "p2b " & to_hstring(ca(0)(6 downto 4)));
            when others =>
                assert not ASSERT_UNEXPECTED
                    report "Other: " &
                        to_hstring(ca(0)) & " " & to_hstring(ca(1))
                    severity failure;
                return "Other: " &
                    to_hstring(ca(0)) & " " & to_hstring(ca(1));
        end case?;
    end;

    function decode_mask(ca : vector_array) return string is
    begin
        if ca(0)(9 downto 8) & ca(1)(9 downto 8) = "1111" then
            return "Mask: " &
                to_hstring(ca(1)(7 downto 0) & ca(0)(7 downto 0));
        else
            return "Invalid mask: " &
                to_hstring(ca(0)) & " "& to_hstring(ca(1));
        end if;
    end;

    function is_simple_nop(ca : vector_array) return boolean is
        variable decode_bits : std_ulogic_vector(3 downto 0);
    begin
        decode_bits := ca(0)(9 downto 8) & ca(1)(9 downto 8);
        case? decode_bits is
            when "1111" | "1110" | "1011" =>
                return ca(0)(7 downto 0) & ca(1)(7 downto 0) = X"FFFF";
            when others =>
                return false;
        end case?;
    end;

    function extra_commands(ca : vector_array) return natural is
        variable decode_bits : std_ulogic_vector(5 downto 0);
    begin
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
            if valid_i then
                if mask_counter > 0 then
                    decode := new string'(decode_mask(ca_command_i.ca));
                    mask_counter <= mask_counter - 1;
                    simple_nop := false;
                else
                    decode := new string'(
                        decode_command(ca_command_i.ca, ca_command_i.ca3));
                    mask_counter <= extra_commands(ca_command_i.ca);
                    simple_nop := is_simple_nop(ca_command_i.ca);
                end if;
                if report_i and (not simple_nop or REPORT_NOP) then
                    write("@ " & to_string(tick_count) & " " & decode.all);
                end if;
            elsif mask_counter > 0 and not ONLY_VALID then
                write("@ " & to_string(tick_count) &
                    " missing mask, count = " & to_string(mask_counter));
                mask_counter <= 0;
            end if;
            tick_count <= tick_count + 1;
        end if;
    end process;
    tick_count_o <= tick_count;
end;
