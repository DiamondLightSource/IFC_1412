-- SG command processing to emulate memory

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_ctrl_timing_defs.all;
use work.gddr6_ctrl_command_defs.all;

use work.sim_phy_defs.all;

entity sim_phy_command is
    port (
        clk_i : in std_ulogic;

        ca_i : in ca_command_t;

        read_address_o : out sg_address_t;
        read_strobe_o : out std_ulogic := '0';
        read_edc_select_o : out std_ulogic := '0';

        write_address_o : out sg_address_t;
        write_mask_o : out sg_write_mask_t;
        write_strobe_o : out std_ulogic := '0';
        write_edc_select_o : out std_ulogic := '0'
    );
end;

architecture arch of sim_phy_command is
    -- Command decoding is a bit tricky as we need to assemble the write mask
    -- which can take 0, 1, or 2 extra ticks, and yet needs to be processed the
    -- correct number of ticks later.
    type command_t is (
        CMD_ACT, CMD_PRE, CMD_RD, CMD_WOM, CMD_WSM, CMD_WDM, CMD_OTHER);
    -- Decodes SG command into one of the above possiblities
    function decode_command(command : ca_command_t) return command_t
    is
        variable decode_bits : std_ulogic_vector(5 downto 0);
    begin
        decode_bits := command.ca(0)(9 downto 8) & command.ca(1)(9 downto 6);
        case? decode_bits is
            when "0-----" => return CMD_ACT;
            when "1000--" => return CMD_PRE;
            when "110100" => return CMD_RD;
            when "110000" => return CMD_WOM;
            when "110001" => return CMD_WSM;
            when "110010" => return CMD_WDM;
            when others =>   return CMD_OTHER;
        end case?;
    end;


    -- Reduces bits to selected width, converts to integer, and warns if any
    -- significant bits were lost
    function slice_bits(
        bits_in : std_ulogic_vector; width : natural) return natural
    is
        variable bits : std_ulogic_vector(bits_in'LENGTH-1 downto 0);
    begin
        bits := bits_in;
        assert bits(bits'LEFT downto width) = (bits'LEFT downto width => '0')
            report "Unwanted bits set: " & to_string(bits_in) & " " &
                to_string(width)
            severity warning;
        return to_integer(unsigned(bits(width-1 downto 0)));
    end;

    -- For all relevant commands returns the selected bank
    function get_bank(command : ca_command_t) return natural is
    begin
        return slice_bits(command.ca(0)(7 downto 4), BANK_BITS);
    end;
    -- For ACT returns selected row
    function get_row(command : ca_command_t) return natural is
    begin
        return slice_bits(command.ca(1) & command.ca(0)(3 downto 0), ROW_BITS);
    end;
    -- For RD/WxM returns selected column
    function get_column(command : ca_command_t) return natural is
    begin
        return slice_bits(
            command.ca(1)(2 downto 0) & command.ca(0)(3 downto 0), COLUMN_BITS);
    end;
    -- For write mask returns mask bits
    function get_mask(command : ca_command_t) return std_ulogic_vector is
    begin
        assert command.ca(1)(9 downto 8) & command.ca(0)(9 downto 8) = "1111"
            report "Invalid mask"
            severity failure;
        return command.ca(1)(7 downto 0) & command.ca(0)(7 downto 0);
    end;

    -- Bank activation state
    signal bank_active : std_ulogic_vector(BANK_RANGE) := (others => '0');
    signal bank_row : integer_array(BANK_RANGE) := (others => 0);


    type write_t is record
        bank : natural;
        column : natural;
        stage : natural;
        enables : std_ulogic_vector(0 to 3);
        even_mask : std_ulogic_vector(15 downto 0);
        odd_mask : std_ulogic_vector(15 downto 0);
        valid : std_ulogic;
    end record;
    constant IDLE_WRITE : write_t := (
        bank => 0,
        column => 0,
        stage => 0,
        enables => (others => 'U'),
        even_mask => (others => 'U'),
        odd_mask => (others => 'U'),
        valid => '0'
    );

    signal next_write_request : write_t := IDLE_WRITE;
    signal write_request : write_t := IDLE_WRITE;


begin
    -- SG command decoding with read and write generation
    vars : process (clk_i)
        -- Command decode state
        variable command : command_t := CMD_OTHER;
        variable bank : natural;
        variable column : natural;
        -- Write masking support
        variable enables : std_ulogic_vector(0 to 3);
        variable mask_count : natural := 0;
        variable loading_mask : boolean := false;
        variable load_mask_extra : boolean;
        -- Read EDC out support
        variable next_select_read_edc : std_ulogic := '0';

        procedure check_bank_state(bank : natural; expected : std_ulogic) is
        begin
            assert bank_active(bank) = expected
                report "Bank " & to_string(bank) & " not in expected state"
                severity failure;
        end;

        procedure do_activate is
        begin
            bank := get_bank(ca_i);
            check_bank_state(bank, '0');
            bank_active(bank) <= '1';
            bank_row(bank) <= get_row(ca_i);
        end;

        procedure do_precharge is
        begin
            if ca_i.ca(1)(4) then
                bank_active <= (others => '0');
            else
                bank_active(get_bank(ca_i)) <= '0';
            end if;
        end;

        procedure do_read_stage0 is
        begin
            bank := get_bank(ca_i);
            column := get_column(ca_i);
            check_bank_state(bank, '1');
            next_select_read_edc := '1';
            read_address_o <= (
                bank => get_bank(ca_i),
                row => bank_row(bank),
                column => get_column(ca_i),
                stage => 0
            );
            read_strobe_o <= '1';
        end;

        procedure do_read_stage1 is
        begin
            read_address_o.stage <= 1;
            read_strobe_o <= '1';
            next_select_read_edc := '1';
        end;

        procedure do_write(count : natural) is
        begin
            mask_count := count;
            bank := get_bank(ca_i);
            column := get_column(ca_i);
            enables := ca_i.ca3;
            check_bank_state(bank, '1');
        end;

        -- This is run at the start of every command while the state saved from
        -- the previous command is still valid.  The write mask is assembled as
        -- appropriate before being handed on to do_write_memory
        procedure do_mask_state is
        begin
            if loading_mask then
                if load_mask_extra then
                    next_write_request.odd_mask <= get_mask(ca_i);
                end if;
                next_write_request.valid <= '1';
                loading_mask := false;
            else
                -- Appropriate defaults
                loading_mask := true;
                load_mask_extra := false;

                -- Look at command from previous state
                case command is
                    when CMD_WOM =>
                        next_write_request.even_mask <= (others => '1');
                        next_write_request.odd_mask <= (others => '1');
                    when CMD_WDM =>
                        next_write_request.even_mask <= get_mask(ca_i);
                        next_write_request.odd_mask <= get_mask(ca_i);
                    when CMD_WSM =>
                        next_write_request.even_mask <= get_mask(ca_i);
                        load_mask_extra := true;
                    when others =>
                        loading_mask := false;
                end case;
                next_write_request.bank <= bank;
                next_write_request.column <= column;
                next_write_request.stage <= 0;
                next_write_request.enables <= enables;
                next_write_request.valid <= '0';
            end if;
        end;

        -- Performs the actual process of writing to memory
        procedure do_write_memory is
        begin
            if write_request.valid then
                if write_request.stage = 0 then
                    write_request.stage <= 1;
                end if;
            end if;
            if write_request.valid = '0' or write_request.stage = 1 then
                write_request <= next_write_request;
            else
                assert not next_write_request.valid
                    report "Missed write request"
                    severity failure;
            end if;
        end;

--         procedure generate_edc_out is
--         begin
--             -- Gather the appropriate EDC output
--             edc_out <= (others => X"AA");       -- Test pattern by default
--             assert not select_read_edc_delay or not select_write_edc_delay
--                 report "Somehow have simultaneous R/W EDC"
--                 severity failure;
--             if select_read_edc_delay then
--                 edc_out <= read_edc_out;
--             elsif select_write_edc_delay then
--                 edc_out <= write_edc_out;
--             end if;
-- 
--             select_write_edc <= write_request.valid;
--         end;

    begin
        if rising_edge(clk_i) then
            -- Default values
            read_strobe_o <= '0';
            -- This assignment aligns select_read_edc with the computation of
            -- read_edc
            read_edc_select_o <= next_select_read_edc;
            next_select_read_edc := '0';
            write_edc_select_o <= write_request.valid;

            -- Write support
            do_mask_state;
            do_write_memory;

            -- Read support
            if command = CMD_RD then
                do_read_stage1;
            end if;

            -- General command decoding, skipping write masks as required
            if mask_count > 0 then
                mask_count := mask_count - 1;
                command := CMD_OTHER;
            else
                command := decode_command(ca_i);
                case command is
                    when CMD_ACT => do_activate;
                    when CMD_PRE => do_precharge;
                    when CMD_RD  => do_read_stage0;
                    when CMD_WOM => do_write(0);
                    when CMD_WDM => do_write(1);
                    when CMD_WSM => do_write(2);
                    when CMD_OTHER =>
                end case;
            end if;

--             generate_edc_out;
        end if;
    end process;


    write_address_o <= (
        bank => write_request.bank,
        row => bank_row(write_request.bank),
        column => write_request.column,
        stage => write_request.stage
    );
    write_mask_o <= (
        even_mask => write_request.even_mask,
        odd_mask => write_request.odd_mask,
        enables => write_request.enables
    );
    write_strobe_o <= write_request.valid;
end;
