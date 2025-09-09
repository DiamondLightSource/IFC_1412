-- Write command generation

-- Generates SG write commands in response to an AXI write request.  The main
-- complication is that, depending on the byte mask pattern there are up to four
-- possible different SG commands that may need to be transmitted in response to
-- a single AXI request.  The principal data flow consists of:
--
--  * An initial decode stage which determines for each channel which pattern of
--    bytes needs to be written.  This will determine the appropriate SG command
--  * The pattern of channel commands is then repeatedly decoded until all
--    channels have been processed
--  * The selected command and channels are then used to generate a core
--    write request which is dispached to the command processor
--
-- Data handling and lookahead is handled separately.  A lot of complexity here
-- is required to ensure that flow control is handled properly and that SG
-- commands can be issued without gaps.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_command_defs.all;
use work.gddr6_ctrl_defs.all;

entity gddr6_ctrl_write is
    port (
        clk_i : in std_ulogic;

        -- AXI interface
        axi_address_i : in unsigned(24 downto 0);
        axi_byte_mask_i : in std_ulogic_vector(127 downto 0);
        axi_valid_i : in std_ulogic;
        axi_ready_o : out std_ulogic := '1';

        -- Outgoing read request with send acknowledgement
        write_request_o : out core_request_t := IDLE_CORE_REQUEST(DIR_WRITE);
        write_ready_i : in std_ulogic
    );
end;

architecture arch of gddr6_ctrl_write is
    -- Types used to decode byte mask
    type decode_t is (
        DECODE_NOP,     -- No bytes set, do not write to this channel
        DECODE_WOM,     -- All bytes sent, can use WOM command to write
        DECODE_WDM,     -- Byte pattern consistent with double mask MDM
        DECODE_WSM      -- Must use WSM
    );
    type decode_array_t is array(0 to 3) of decode_t;

    subtype half_byte_mask_t is vector_array(0 to 3)(15 downto 0);

    -- Incoming write request decoded and pipelined
    signal pattern_decode : decode_array_t;
    signal command_address_in : unsigned(24 downto 0);
    signal even_byte_mask_in : half_byte_mask_t;
    signal odd_byte_mask_in : half_byte_mask_t;
    -- Array of flags for communication between decode stages
    signal pending_channels : std_ulogic_vector(0 to 3) := "0000";
    -- Command decoded for output to command stream
    signal command_decode : decode_t;
    signal command_enables : std_ulogic_vector(0 to 3);
    signal command_address : unsigned(24 downto 0);
    signal command_advance : std_ulogic;
    signal mask_index : natural range 0 to 3;
    signal even_byte_mask : half_byte_mask_t;
    signal odd_byte_mask : half_byte_mask_t;

    -- State machine for command and mask generation
    type write_state_t is (
        WRITE_IDLE,         -- Waiting for commands to process
        WRITE_COMMAND,      -- Emit currently selected command
        WRITE_EVEN_MASK,    -- Emit even bits byte mask
        WRITE_ODD_MASK      -- Emit odd bits byte mask
    );
    signal write_state : write_state_t := WRITE_IDLE;


    -- Performs decode and rearrangement of byte mask for all four channels
    procedure decode_byte_mask(
        byte_mask : std_ulogic_vector(127 downto 0);
        signal even_bytes_out : out half_byte_mask_t;
        signal odd_bytes_out  : out half_byte_mask_t;
        signal decode_array : out decode_array_t)
    is
        -- Extract even or odd bits from byte mask by channel
        function channel_strobes(
            mask : std_ulogic_vector(127 downto 0);
            offset : natural) return half_byte_mask_t
        is
            variable result : half_byte_mask_t;
        begin
            for ch in 0 to 3 loop
                for bit in 0 to 15 loop
                    result(ch)(bit) := mask(32*ch + 2*bit + offset);
                end loop;
            end loop;
            return result;
        end;

        -- Decode the byte mask for a single channel
        function decode_one_mask(
            even_bytes : std_ulogic_vector(15 downto 0);
            odd_bytes : std_ulogic_vector(15 downto 0)) return decode_t is
        begin
            if vector_or(even_bytes & odd_bytes) = '0' then
                -- Nothing written to this channel
                return DECODE_NOP;
            elsif vector_and(even_bytes & odd_bytes) = '1' then
                -- All bytes written to this channel
                return DECODE_WOM;
            elsif even_bytes = odd_bytes then
                -- Byte mask to this channel supports double byte resolution
                return DECODE_WDM;
            else
                -- Need full byte mask resolution on this channel
                return DECODE_WSM;
            end if;
        end;

        variable even_bytes : half_byte_mask_t;
        variable odd_bytes  : half_byte_mask_t;

    begin
        even_bytes := channel_strobes(byte_mask, 0);
        odd_bytes  := channel_strobes(byte_mask, 1);
        even_bytes_out <= even_bytes;
        odd_bytes_out <= odd_bytes;
        for ch in 0 to 3 loop
            decode_array(ch) <= decode_one_mask(even_bytes(ch), odd_bytes(ch));
        end loop;
    end;

    -- Determines the next command to emit.  There are four possible cases (NOP
    -- for all channels needs special handling).  The scheduled channel(s) are
    -- ticked off the pending list and the output identifies the next command to
    -- emit, the channel enables to use, and the mask_index to use.
    procedure decode_next_command(
        decodes : decode_array_t;
        signal pending : inout std_ulogic_vector(0 to 3);
        signal command : out decode_t;
        signal enables : out std_ulogic_vector(0 to 3);
        signal mask_index : out natural range 0 to 3;
        variable last_command : out std_ulogic)
    is
        -- Returns bit array matching given decode condition
        impure function match(decode : decode_t) return std_ulogic_vector
        is
            variable result : std_ulogic_vector(0 to 3);
        begin
            for ch in 0 to 3 loop
                result(ch) := to_std_ulogic(decodes(ch) = decode);
            end loop;
            return result and pending;
        end;

        -- Isolates a single bit from a (non zero) mask
        function one_bit(mask : std_ulogic_vector) return std_ulogic_vector is
        begin
            return std_ulogic_vector(signed(mask) and -signed(mask));
        end;

        -- Returns index of lowest most set bit in mask
        function find_bit(mask : std_ulogic_vector(0 to 3)) return natural is
        begin
            for i in 0 to 3 loop
                if mask(i) then
                    return i;
                end if;
            end loop;
            return 0;
        end;

        -- Decodes of the four conditions
        variable nop_mask : std_ulogic_vector(0 to 3);
        variable wom_mask : std_ulogic_vector(0 to 3);
        variable wdm_mask : std_ulogic_vector(0 to 3);
        variable wsm_mask : std_ulogic_vector(0 to 3);
        -- Mask of channels handled in this update
        variable enables_out : std_ulogic_vector(0 to 3);
        variable pending_out : std_ulogic_vector(0 to 3);

    begin
        nop_mask := match(DECODE_NOP);
        wom_mask := match(DECODE_WOM);
        wdm_mask := match(DECODE_WDM);
        wsm_mask := match(DECODE_WSM);

        -- Work through the four possible cases
        if vector_and(nop_mask) then
            -- All four channels are NOPs, we need to issue a NOP, mark all
            -- commands as done
            command <= DECODE_NOP;
            enables_out := "0000";
        elsif vector_or(wom_mask) then
            -- Handle WOM commands first, we can process them all in one go
            command <= DECODE_WOM;
            enables_out := wom_mask;
        else
            -- For the byte masked commands we'll issue these one channel at a
            -- time, as the chances of being able to share channels is very low
            if vector_or(wdm_mask) then
                -- Double byte mask commands
                command <= DECODE_WDM;
                enables_out := one_bit(wdm_mask);
            else -- Must be vector_or(wsm_mask)
                -- All other cases tested, must be single byte mask commands
                command <= DECODE_WSM;
                enables_out := one_bit(wsm_mask);
            end if;
        end if;
        pending_out := pending and not (enables_out or nop_mask);

        pending <= pending_out;
        enables <= enables_out;
        mask_index <= find_bit(enables_out);
        last_command := to_std_ulogic(pending_out = "0000");
    end;

    -- Computes the approprate command request for the current command
    function write_command(
        decode : decode_t;
        address : unsigned(24 downto 0);
        enables : std_ulogic_vector(0 to 3);
        last_command : std_ulogic) return core_request_t
    is
        variable row : unsigned(13 downto 0);
        variable bank : unsigned(3 downto 0);
        variable column : unsigned(6 downto 0);
        variable command : ca_command_t;
        variable next_extra : std_ulogic;
    begin
        bank := address(BANK_RANGE);
        row := address(ROW_RANGE);
        column := address(COLUMN_RANGE);
        case decode is
            when DECODE_NOP | DECODE_WOM =>
                -- We still need to issue a write command even if there is
                -- nothing to write, this is required to keep data flow and
                -- bank state flags correctly in step.
                command := SG_WOM(bank, column, enables);
                next_extra := '0';
            when DECODE_WDM =>
                command := SG_WDM(bank, column, enables);
                next_extra := '1';
            when DECODE_WSM =>
                command := SG_WSM(bank, column, enables);
                next_extra := '1';
        end case;

        return (
            direction => DIR_WRITE,
            write_advance => last_command,
            bank => bank,
            row => row,
            command => command,
            extra => '0', next_extra => next_extra,
            valid => '1'
        );
    end;

    -- Computes command for writing a single mask
    function write_mask(
        mask : std_ulogic_vector(15 downto 0);
        next_extra : std_ulogic) return core_request_t is
    begin
        return (
            direction => DIR_WRITE,
            write_advance => '-',
            bank => (others => '-'),
            row => (others => '-'),
            command => SG_write_mask(mask),
            extra => '1', next_extra => next_extra,
            valid => '1'
        );
    end;

    -- Update the write state machine generating as many write requests as
    -- necessary for a single decoded command: a single command for WOM, command
    -- plus mask for WDM, and command plus double mask for WSM.
    procedure advance_write_state(
        signal state : inout write_state_t;
        signal write_request : inout core_request_t;
        variable next_command : out std_ulogic)
    is
        procedure goto_next_command is
        begin
            if pending_channels = "0000" then
                state <= WRITE_IDLE;
            else
                state <= WRITE_COMMAND;
            end if;
            next_command := '1';
        end;

    begin
        next_command := '0';

        case state is
            when WRITE_IDLE =>
                -- No decoded command yet, wait until ready
                if write_ready_i then
                    write_request.valid <= '0';
                end if;
                goto_next_command;
            when WRITE_COMMAND =>
                -- First part of command
                if write_ready_i or not write_request.valid then
                    write_request <= write_command(
                        command_decode, command_address,
                        command_enables, command_advance);
                    case command_decode is
                        when DECODE_NOP | DECODE_WOM =>
                            goto_next_command;
                        when DECODE_WDM =>
                            state <= WRITE_ODD_MASK;
                        when DECODE_WSM =>
                            state <= WRITE_EVEN_MASK;
                    end case;
                end if;
            when WRITE_EVEN_MASK =>
                -- Even part of two part byte mask
                if write_ready_i then
                    write_request <=
                        write_mask(even_byte_mask(mask_index), '1');
                    state <= WRITE_ODD_MASK;
                end if;
            when WRITE_ODD_MASK =>
                -- Odd part of two part mask or entire single part mask
                if write_ready_i then
                    write_request <=
                        write_mask(odd_byte_mask(mask_index), '0');
                    goto_next_command;
                end if;
        end case;
    end;

begin
    proc : process (clk_i)
        -- Set when sending state machine is ready for next command
        variable next_command : std_ulogic;
        variable last_command : std_ulogic;
    begin
        if rising_edge(clk_i) then
            -- Generate output according to the decoded command and determine
            -- whether to advance to the next command.  Logically this should
            -- be last, but we need the combinatorial flag next_command first
            advance_write_state(write_state, write_request_o, next_command);

            if pending_channels = "0000" then
                -- Load next AXI write request once we've finished with the
                -- previous one
                if axi_valid_i and axi_ready_o then
                    -- Decode incoming byte mask
                    decode_byte_mask(
                        axi_byte_mask_i,
                        even_byte_mask_in, odd_byte_mask_in, pattern_decode);
                    command_address_in <= axi_address_i;
                    -- Reset command decode state and run
                    pending_channels <= "1111";
                    axi_ready_o <= '0';
                elsif write_ready_i then
                    -- We can get into this state if transition to the next
                    -- command has been held up waiting to send this command
                    axi_ready_o <= '1';
                end if;
            elsif next_command then
                -- Decode the next command.  If this is the last command in
                -- for this write request then pending_channels will be zero
                -- and axi_ready_o is set to enable loading a new command.
                decode_next_command(
                    pattern_decode, pending_channels,
                    command_decode, command_enables, mask_index,
                    last_command);
                command_advance <= last_command;
                axi_ready_o <= last_command;
            end if;

            if pending_channels = "1111" and next_command = '1' then
                command_address <= command_address_in;
                even_byte_mask <= even_byte_mask_in;
                odd_byte_mask <= odd_byte_mask_in;
            end if;
        end if;
    end process;
end;
