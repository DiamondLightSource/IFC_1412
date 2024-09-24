-- Simulates PHY interface and SG memory

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_ctrl_timing_defs.all;
use work.gddr6_ctrl_command_defs.all;

use work.sim_phy_defs.all;

entity sim_phy is
    port (
        clk_i : in std_ulogic;

        ca_i : in phy_ca_t;
        dq_i : in phy_dq_out_t;
        dq_o : out phy_dq_in_t
    );
end;

architecture arch of sim_phy is
    signal tick_count : natural;

    procedure write(prefix : string; message : string) is
        variable linebuffer : line;
    begin
        write(linebuffer,
            "%" & to_string(tick_count) & " " & prefix & " " & message);
        writeline(output, linebuffer);
    end;

    -- All these constants are, alas, copied from _ctrl_data
    constant MUX_OUTPUT_DELAY : natural := 1;
    constant MUX_INPUT_DELAY : natural := 1;
    constant TX_BITSLICE_DELAY : natural := 1;
    constant RX_BITSLICE_DELAY : natural := 1;
    constant TRI_BITSLICE_DELAY : natural := 2;
    constant CA_OUTPUT_DELAY : natural := MUX_OUTPUT_DELAY + 3;
    constant OE_OUTPUT_DELAY : natural :=
        MUX_OUTPUT_DELAY + 1 + TRI_BITSLICE_DELAY;
    constant TX_OUTPUT_DELAY : natural :=
        MUX_OUTPUT_DELAY + 2 + TX_BITSLICE_DELAY;
    constant TX_EDC_DELAY : natural := MUX_OUTPUT_DELAY + 2 + MUX_INPUT_DELAY;
    constant RX_INPUT_DELAY : natural :=
        RX_BITSLICE_DELAY + 2 + MUX_INPUT_DELAY;
    constant RX_EDC_DELAY : natural := RX_BITSLICE_DELAY + 2 + MUX_INPUT_DELAY;
    constant EDC_INPUT_DELAY : natural :=
        RX_BITSLICE_DELAY + 1 + MUX_INPUT_DELAY;


    -- Closing the loop for writes.  The transmitter _ctrl_data should be using
    -- the following delay calculation:
    --  CA_OUTPUT_DELAY + WLmrs - TX_OUTPUT_DELAY
    -- Our write processing actually takes place 4 ticks after we see

    -- The delay from ca_i a write command to writing the associated data is:
    --  ca_i (CA = WOM/WSM/WDM)
    --      =(CA_OUTPUT_DELAY-CA_DELAY_OFFSET)=> ca_in
    --      => 
    constant WRITE_PROCESS_DELAY : natural := 4;
    constant WRITE_DELAY : natural :=
        WRITE_PROCESS_DELAY - WLmrs + TX_OUTPUT_DELAY;
    constant READ_DELAY : natural := RLmrs + RX_INPUT_DELAY - 1;

    -- Delay to align write_edc returned during write.  Needs to take 1 tick
    -- internal computation of EDC into account
    constant WRITE_EDC_DELAY : natural := TX_EDC_DELAY - 1;
    -- edc_read is sent at the same time as received data, so for alignment we
    -- need to subtract a tick for computing the CRC
    constant READ_EDC_DELAY : natural := READ_DELAY - 1;


    signal read_address : sg_address_t;
    signal read_strobe : std_ulogic := '0';
    signal read_data : phy_data_t;
    signal read_data_delayed : phy_data_t;
    signal read_edc : phy_edc_t;
    signal read_edc_delayed : phy_edc_t;

    signal write_data : phy_data_t;
    signal write_edc : phy_edc_t;
    signal write_edc_delayed : phy_edc_t;

    -- EDC out selection, emulating SG EDC generation
    signal select_read_edc : std_ulogic := '0';
    signal select_write_edc : std_ulogic := '0';
    signal select_read_edc_delay : std_ulogic := '0';
    signal select_write_edc_delay : std_ulogic := '0';
    signal read_edc_out : phy_edc_t;
    signal write_edc_out : phy_edc_t;
    signal edc_out : phy_edc_t;


    -- The CA output from CTRL is one tick later than the reference above, we
    -- need to take this into account in the SG simulation here by delaying ca_i
    -- by one tick.  We might as well turn ca_phy_t back into ca_command_t at
    -- the same time.
    constant CA_DELAY_OFFSET : natural := 1;
    signal ca_in : ca_command_t;

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


    signal decode_stage : natural := 0;


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


    -- Helper functions for generating delays
    function to_std_ulogic_vector(value : vector_array) return std_ulogic_vector
    is
        constant ARRAY_LENGTH : natural := value'LENGTH;
        constant VECTOR_LENGTH : natural := value'ELEMENT'LENGTH;
        variable result :
            std_logic_vector(ARRAY_LENGTH*VECTOR_LENGTH-1 downto 0);
    begin
        for i in 0 to ARRAY_LENGTH-1 loop
            for j in 0 to VECTOR_LENGTH-1 loop
                result(i * VECTOR_LENGTH + j) := value(i)(j);
            end loop;
        end loop;
        return result;
    end;

    function to_vector_array(value : std_ulogic_vector) return vector_array
    is
        constant VECTOR_LENGTH : natural := 8;
        constant ARRAY_LENGTH : natural := value'LENGTH / VECTOR_LENGTH;
        variable result :
            vector_array(ARRAY_LENGTH-1 downto 0)(VECTOR_LENGTH-1 downto 0);
    begin
        for i in 0 to ARRAY_LENGTH-1 loop
            for j in 0 to VECTOR_LENGTH-1 loop
                result(i)(j) := value(i * VECTOR_LENGTH + j);
            end loop;
        end loop;
        return result;
    end;

    function to_phy_edc_t(
        value : std_ulogic_vector(63 downto 0)) return phy_edc_t is
    begin
        return to_vector_array(value);
    end;


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
    -- Logs commands as they are received at the memory
    decode : entity work.decode_commands generic map (
        ASSERT_UNEXPECTED => true
    ) port map (
        clk_i => clk_i,
        ca_command_i => ca_in,
        tick_count_o => tick_count
    );

    memory : entity work.sim_phy_memory port map (
        clk_i => clk_i,

        read_address_i => read_address,
        read_strobe_i => read_strobe,
        read_data_o => read_data,

        write_address_i => (
            bank => write_request.bank,
            row => bank_row(write_request.bank),
            column => write_request.column,
            stage => write_request.stage),
        write_mask_i => (
            even_mask => write_request.even_mask,
            odd_mask => write_request.odd_mask,
            enables => write_request.enables),
        write_strobe_i => write_request.valid,
        write_data_i => write_data
    );

    -- Delay CA to match delay at SG
    delay_ca_sg : entity work.fixed_delay generic map (
        DELAY => CA_OUTPUT_DELAY - CA_DELAY_OFFSET,
        WIDTH => 24,
        INITIAL => '1'
    ) port map (
        clk_i => clk_i,
        data_i(9 downto 0) => ca_i.ca(0),
        data_i(19 downto 10) => ca_i.ca(1),
        data_i(23 downto 20) => ca_i.ca3,
        data_o(9 downto 0) => ca_in.ca(0),
        data_o(19 downto 10) => ca_in.ca(1),
        data_o(23 downto 20) => ca_in.ca3
    );


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
            bank := get_bank(ca_in);
            check_bank_state(bank, '0');
            bank_active(bank) <= '1';
            bank_row(bank) <= get_row(ca_in);
        end;

        procedure do_precharge is
        begin
            if ca_in.ca(1)(4) then
                bank_active <= (others => '0');
            else
                bank_active(get_bank(ca_in)) <= '0';
            end if;
        end;

        procedure do_read_stage0 is
        begin
            bank := get_bank(ca_in);
            column := get_column(ca_in);
            check_bank_state(bank, '1');
            next_select_read_edc := '1';
            read_address <= (
                bank => get_bank(ca_in),
                row => bank_row(bank),
                column => get_column(ca_in),
                stage => 0
            );
            read_strobe <= '1';
        end;

        procedure do_read_stage1 is
        begin
            read_address.stage <= 1;
            read_strobe <= '1';
            next_select_read_edc := '1';
        end;

        procedure do_write(count : natural) is
        begin
            mask_count := count;
            bank := get_bank(ca_in);
            column := get_column(ca_in);
            enables := ca_in.ca3;
            check_bank_state(bank, '1');
        end;

        -- This is run at the start of every command while the state saved from
        -- the previous command is still valid.  The write mask is assembled as
        -- appropriate before being handed on to do_write_memory
        procedure do_mask_state is
        begin
            if loading_mask then
                if load_mask_extra then
                    next_write_request.odd_mask <= get_mask(ca_in);
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
                        next_write_request.even_mask <= get_mask(ca_in);
                        next_write_request.odd_mask <= get_mask(ca_in);
                    when CMD_WSM =>
                        next_write_request.even_mask <= get_mask(ca_in);
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

        procedure generate_edc_out is
        begin
            -- Gather the appropriate EDC output
            edc_out <= (others => X"AA");       -- Test pattern by default
            assert not select_read_edc_delay or not select_write_edc_delay
                report "Somehow have simultaneous R/W EDC"
                severity failure;
            if select_read_edc_delay then
                edc_out <= read_edc_out;
            elsif select_write_edc_delay then
                edc_out <= write_edc_out;
            end if;

            select_write_edc <= write_request.valid;
        end;

    begin
        if rising_edge(clk_i) then
            -- Default values
            read_strobe <= '0';
            -- This assignment aligns select_read_edc with the computation of
            -- read_edc
            select_read_edc <= next_select_read_edc;
            next_select_read_edc := '0';

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
                command := decode_command(ca_in);
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

            generate_edc_out;
        end if;
    end process;


    -- Ensure read data arrives when expected by CTRL
    delay_read : entity work.fixed_delay generic map (
        WIDTH => 512,
--         DELAY => READ_DELAY,
        DELAY => READ_DELAY - 1,
        INITIAL => 'U'
    ) port map (
        clk_i => clk_i,
        data_i => to_std_ulogic_vector(read_data),
        to_vector_array(data_o) => read_data_delayed
    );


    -- Align write data for when we're ready to process it
    delay_write : entity work.fixed_delay generic map (
        WIDTH => 512,
        DELAY => WRITE_DELAY,
        INITIAL => 'U'
    ) port map (
        clk_i => clk_i,
        data_i => to_std_ulogic_vector(dq_i.data),
        to_vector_array(data_o) => write_data
    );


    -- Generate EDC in response to write and delay as required
    write_edc_inst : entity work.gddr6_phy_crc port map (
        clk_i => clk_i,
        data_i => dq_i.data,
        dbi_n_i => (others => (others => '1')),
        edc_o => write_edc
    );
    write_edc_delay_inst : entity work.fixed_delay generic map (
        WIDTH => 64,
        DELAY => WRITE_EDC_DELAY
    ) port map (
        clk_i => clk_i,
        data_i => to_std_ulogic_vector(write_edc),
        to_vector_array(data_o) => write_edc_delayed
    );


    -- Generate EDC in response to read and delay as required
    read_edc_inst : entity work.gddr6_phy_crc port map (
        clk_i => clk_i,
        data_i => read_data,
        dbi_n_i => (others => (others => '1')),
        edc_o => read_edc
    );
    read_edc_delay_inst : entity work.fixed_delay generic map (
        WIDTH => 64,
        DELAY => READ_EDC_DELAY - 1
    ) port map (
        clk_i => clk_i,
        data_i => to_std_ulogic_vector(read_edc),
        to_vector_array(data_o) => read_edc_delayed
    );
    read_edc_select_delay : entity work.fixed_delay generic map (
        DELAY => READ_EDC_DELAY
    ) port map (
        clk_i => clk_i,
        data_i(0) => select_read_edc,
        data_o(0) => select_read_edc_delay
    );
    read_edc_out <= read_edc_delayed;


    dq_o <= (
        data => read_data_delayed,
        edc_in => edc_out,
        edc_write => write_edc_delayed,
        edc_read => read_edc_delayed
    );
end;
