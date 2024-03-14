-- Command flow for read/write commands

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_command_defs.all;
use work.gddr6_ctrl_core_defs.all;

entity gddr6_ctrl_request is
    port (
        clk_i : in std_ulogic;

        -- Selected request from read/write multiplexer
        mux_request_i : in core_request_t;
        mux_ready_o : out std_ulogic;

        -- Command completion notification
        write_request_sent_o : out std_ulogic := '0';
        read_request_sent_o : out std_ulogic := '0';

        -- Check bank open and reserve
        bank_open_o : out bank_open_t := IDLE_OPEN_REQUEST;
        bank_open_ok_i : in std_ulogic;
        -- Request to open bank.  This is asserted while an open bank request
        -- is being rejected
        bank_open_request_o : out std_logic := '0';

        -- Bank read/write request
        out_request_o : out out_request_t := IDLE_OUT_REQUEST;
        out_request_ok_i : in std_ulogic;
        -- Probably want out_request_extra as a separate field
        out_request_extra_o : out std_ulogic;

        -- CA Commands out to PHY
        command_o : out ca_command_t;
        command_valid_o : out std_ulogic := '0'
    );
end;

architecture arch of gddr6_ctrl_request is
    type mux_t is (SEL_IN, SEL_OUT);

    -- Bank validation stage
    signal bank_in : core_request_t := IDLE_CORE_REQUEST;
    signal bank_out : core_request_t := IDLE_CORE_REQUEST;
    signal bank_ok : std_ulogic := '0';
    signal bank_out_valid : std_ulogic;
    signal enable_bank_in : std_ulogic;
    signal enable_bank_out : std_ulogic;

    -- Bank test generation and control
    signal bank_mux_sel : mux_t := SEL_IN;
    signal bank_test : bank_open_t;
    signal load_test_bank : std_ulogic := '1';

    -- Request validation stage
    signal request_in : core_request_t := IDLE_CORE_REQUEST;
    signal request_out : core_request_t := IDLE_CORE_REQUEST;
    signal request_ok : std_ulogic := '0';
    signal enable_request_in : std_ulogic;
    signal enable_request_out : std_ulogic;

    -- Request test generation and control
    signal request_test : out_request_t;
    signal load_test_request : std_ulogic := '1';

begin
    -- Propagate enables from output back to input.  At each stage we forward
    -- the buffer if allowed and not blocked.  This whole chain back to
    -- mux_ready_o is combinatorial.
    enable_request_out <=
        not request_out.valid or request_ok or request_out.extra;
    -- We must ensure that the request validation stage never has two valid
    -- commands at the same time (the banks checker doesn't want to have to
    -- deal with more than one command in transit at a time).
    enable_request_in <=
        -- Block everything while waiting for output command ready to send
        request_ok when request_out.valid and not request_out.extra else
        -- Only accept extra when request_in is a command
        bank_out.extra when request_in.valid and not request_in.extra else
        -- All other states are unconditional acceptors
        '1';

    bank_out_valid <=
        bank_out.valid and (bank_ok or bank_out.extra) and enable_request_in;
    enable_bank_out <=
        not bank_out.valid or (bank_out_valid and enable_request_in);
    enable_bank_in <= not bank_in.valid or enable_bank_out;
    mux_ready_o <= enable_bank_in;


    -- Multiplexers for bank and request tests
    process (all) begin
        case bank_mux_sel is
            when SEL_IN =>
                bank_test <= (
                    bank => mux_request_i.bank,
                    row => mux_request_i.row,
                    valid => mux_request_i.valid and not mux_request_i.extra
                );
            when SEL_OUT =>
                bank_test <= (
                    bank => bank_in.bank,
                    row => bank_in.row,
                    valid => bank_in.valid and not bank_in.extra
                );
        end case;

        request_test <= (
            direction => bank_out.direction,
            bank => bank_out.bank,
            auto_precharge => bank_out.precharge,
            valid => bank_out.valid and not bank_out.extra and bank_ok
        );
    end process;


    proc : process (clk_i)
        variable bank_loaded : std_ulogic;
        variable block_bank : std_ulogic;

    begin
        if rising_edge(clk_i) then
            -- Manage flow of data through the four stage pipeline
            if enable_bank_in then
                bank_in <= mux_request_i;
            end if;
            if enable_bank_out then
                bank_out <= bank_in;
            end if;
            if enable_request_in then
                request_in <= bank_out;
                -- Qualify so that we only load passing bank commands
                request_in.valid <= bank_out_valid;
            elsif enable_request_out then
                request_in.valid <= '0';
            end if;
            if enable_request_out then
                request_out <= request_in;
            end if;


            -- Advance bank test
            block_bank :=
                (out_request_o.valid and not out_request_ok_i) or
                (bank_out.valid and bank_out.extra);
            if load_test_bank then
                load_test_bank <= not bank_test.valid;
                bank_open_o <= bank_test;
            elsif bank_open_ok_i and not block_bank then
                load_test_bank <= '1';
                bank_open_o.valid <= '0';
            end if;
            bank_ok <= bank_open_ok_i and bank_open_o.valid and not block_bank;

            -- Update bank mux selector
            bank_loaded :=
                enable_bank_in and mux_request_i.valid and
                not mux_request_i.extra;
            if bank_loaded and not load_test_bank then
                bank_mux_sel <= SEL_OUT;
            elsif not bank_loaded and load_test_bank then
                bank_mux_sel <= SEL_IN;
            end if;

            -- Advance request test
            if load_test_request then
                load_test_request <= not request_test.valid;
                out_request_o <= request_test;
            elsif out_request_ok_i then
                load_test_request <= '1';
                out_request_o.valid <= '0';
            end if;
            request_ok <= out_request_ok_i and out_request_o.valid;
            out_request_extra_o <= bank_out.valid and bank_out.extra;


            -- Bank request generation: assert this while we're blocked waiting
            -- for a bank open request to complete
            bank_open_request_o <=
                bank_open_o.valid and not block_bank and not bank_open_ok_i;

            -- Output generation
            command_o <= request_out.command;
            command_valid_o <= request_ok or request_out.extra;

            -- Command completion
            case request_out.direction is
                when DIR_READ =>
                    write_request_sent_o <= '0';
                    read_request_sent_o <= request_ok;
                when DIR_WRITE =>
                    write_request_sent_o <= request_ok;
                    read_request_sent_o <= '0';
            end case;
        end if;
    end process;
end;
