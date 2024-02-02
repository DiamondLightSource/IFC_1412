-- SGRAM command definitions

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

package gddr6_ctrl_commands is
    -- SGRAM commands
    type ca_command_t is record
        ca : vector_array(0 to 1)(9 downto 0);
        ca3 : std_ulogic_vector(0 to 3);
    end record;

    -- Idle command
    constant SG_NOP : ca_command_t
        := ((b"11_1111_1111", b"11_1111_1111"), "0000");

    -- Set mode register
    function SG_MRS(
        mode : std_ulogic_vector(3 downto 0);
        op : std_ulogic_vector(11 downto 0)) return ca_command_t;

    -- Refresh all banks or selected pair of banks
    function SG_REFp2b(bank_pair : unsigned(2 downto 0)) return ca_command_t;
    constant SG_REFab : ca_command_t
        := ((b"10_1111_1111", b"01_1111_1111"), "0000");

    -- Activate selected bank with selected row
    function SG_ACT(
        bank : unsigned(3 downto 0); row : unsigned(13 downto 0))
        return ca_command_t;

    -- Precharge (deactivate) selected bank or all banks
    function SG_PREpb(bank : unsigned(3 downto 0)) return ca_command_t;
    constant SG_PREab : ca_command_t
        := ((b"10_1111_1111", b"00_111_1_1111"), "0000");

    -- Read request on active bank.  If auto is set the bank is precharged on
    -- completion of the read
    function SG_RD(
        bank : unsigned(3 downto 0); column : unsigned(6 downto 0);
        auto : std_ulogic := '0') return ca_command_t;

    -- Write without mask
    function SG_WOM(
        bank : unsigned(3 downto 0); column : unsigned(6 downto 0);
        ce : std_ulogic_vector(0 to 3) := "1111"; auto : std_ulogic := '0')
        return ca_command_t;
    -- Write with double byte mask (must be followed by mask command)
    function SG_WDM(
        bank : unsigned(3 downto 0); column : unsigned(6 downto 0);
        ce : std_ulogic_vector(0 to 3); auto : std_ulogic := '0')
        return ca_command_t;
    -- Write with single byte mask (must be followed by two mask commands)
    function SG_WSM(
        bank : unsigned(3 downto 0); column : unsigned(6 downto 0);
        ce : std_ulogic_vector(0 to 3); auto : std_ulogic := '0')
        return ca_command_t;
    -- Mask command, must follow WDM or WSM as appropriate
    function SG_write_mask(byte_mask : std_ulogic_vector(15 downto 0))
        return ca_command_t;
end;

package body gddr6_ctrl_commands is
    function SG_MRS(
        mode : std_ulogic_vector(3 downto 0);
        op : std_ulogic_vector(11 downto 0)) return ca_command_t is
    begin
        return (("10" & mode & op(3 downto 0), "10" & op(11 downto 4)), "0000");
    end;

    function SG_REFp2b(bank_pair : unsigned(2 downto 0)) return ca_command_t
    is
        variable bank_pair_bits : std_ulogic_vector(2 downto 0);
    begin
        bank_pair_bits := std_ulogic_vector(bank_pair);
        return ((
            b"10_1" & bank_pair_bits & "1111", b"10_111_0_1111"), "0000");
    end;

    function SG_ACT(
        bank : unsigned(3 downto 0); row : unsigned(13 downto 0))
        return ca_command_t
    is
        variable bank_bits : std_ulogic_vector(3 downto 0);
        variable row_bits : std_ulogic_vector(13 downto 0);
    begin
        bank_bits := std_ulogic_vector(bank);
        row_bits := std_ulogic_vector(row);
        return ((
            "01" & bank_bits & row_bits(3 downto 0),
            row_bits(13 downto 4)), "0000");
    end;

    function SG_PREpb(bank : unsigned(3 downto 0)) return ca_command_t
    is
        variable bank_bits : std_ulogic_vector(3 downto 0);
    begin
        bank_bits := std_ulogic_vector(bank);
        return (("10" & bank_bits & "1111", b"00_111_0_1111"), "0000");
    end;

    function SG_RD(
        bank : unsigned(3 downto 0); column : unsigned(6 downto 0);
        auto : std_ulogic := '0') return ca_command_t
    is
        variable bank_bits : std_ulogic_vector(3 downto 0);
        variable column_bits : std_ulogic_vector(6 downto 0);
    begin
        bank_bits := std_ulogic_vector(bank);
        column_bits := std_ulogic_vector(column);
        return ((
            "11" & bank_bits & column_bits(3 downto 0),
            b"0100_1" & auto & "1" & column_bits(6 downto 4)), "0000");
    end;

    function SG_WOM(
        bank : unsigned(3 downto 0); column : unsigned(6 downto 0);
        ce : std_ulogic_vector(0 to 3) := "1111"; auto : std_ulogic := '0')
        return ca_command_t
    is
        variable bank_bits : std_ulogic_vector(3 downto 0);
        variable column_bits : std_ulogic_vector(6 downto 0);
    begin
        bank_bits := std_ulogic_vector(bank);
        column_bits := std_ulogic_vector(column);
        return ((
            "11" & bank_bits & column_bits(3 downto 0),
            b"0000_1" & auto & "0" & column_bits(6 downto 4)), ce);
    end;

    function SG_WDM(
        bank : unsigned(3 downto 0); column : unsigned(6 downto 0);
        ce : std_ulogic_vector(0 to 3); auto : std_ulogic := '0')
        return ca_command_t
    is
        variable bank_bits : std_ulogic_vector(3 downto 0);
        variable column_bits : std_ulogic_vector(6 downto 0);
    begin
        bank_bits := std_ulogic_vector(bank);
        column_bits := std_ulogic_vector(column);
        return ((
            "11" & bank_bits & column_bits(3 downto 0),
            b"0010_1" & auto & "0" & column_bits(6 downto 4)), ce);
    end;

    function SG_WSM(
        bank : unsigned(3 downto 0); column : unsigned(6 downto 0);
        ce : std_ulogic_vector(0 to 3); auto : std_ulogic := '0')
        return ca_command_t
    is
        variable bank_bits : std_ulogic_vector(3 downto 0);
        variable column_bits : std_ulogic_vector(6 downto 0);
    begin
        bank_bits := std_ulogic_vector(bank);
        column_bits := std_ulogic_vector(column);
        return ((
            "11" & bank_bits & column_bits(3 downto 0),
            b"0001_1" & auto & "0" & column_bits(6 downto 4)), ce);
    end;

    function SG_write_mask(byte_mask : std_ulogic_vector(15 downto 0))
        return ca_command_t is
    begin
        return ((
            "11" & byte_mask(7 downto 0),
            "11" & byte_mask(15 downto 8)), "0000");
    end;
end;
