library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

use work.gddr6_ctrl_command_defs.all;
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

    signal bank_status : bank_status_t := (
        active => (3 => '1', others => '0'),
        rows => (3 => 14X"1234", others => (others => 'U')),
        read_ready => (others => '1'),
        write_ready => (others => '1'),
        activate_ready => (others => '0'),
        precharge_ready => (others => '0'),
        refresh_ready => (others => '0')
    );
    signal bank_response : bank_rw_response_t;
    signal direction : sg_direction_t;
    signal write_request : core_request_t;
    signal write_request_extra : std_ulogic;
    signal write_request_ready : std_ulogic;
    signal write_request_sent : std_ulogic;
    signal read_request : core_request_t;
    signal read_request_ready : std_ulogic;
    signal read_request_sent : std_ulogic;
    signal admin_command : ca_command_t;
    signal admin_command_valid : std_ulogic;
    signal admin_command_ready : std_ulogic;
    signal open_bank_valid : std_ulogic;
    signal open_bank : unsigned(3 downto 0);
    signal open_bank_row : unsigned(13 downto 0);
    signal ca_command : ca_command_t;

    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

    signal tick_count : natural := 0;

begin
    clk <= not clk after 2 ns;

    command : entity work.gddr6_ctrl_command port map (
        clk_i => clk,

        bank_status_i => bank_status,
        bank_response_o => bank_response,

        direction_i => direction,

        write_request_i => write_request,
        write_request_extra_i => write_request_extra,
        write_request_ready_o => write_request_ready,
        write_request_sent_o => write_request_sent,

        read_request_i => read_request,
        read_request_ready_o => read_request_ready,
        read_request_sent_o => read_request_sent,

        admin_command_i => admin_command,
        admin_command_valid_i => admin_command_valid,
        admin_command_ready_o => admin_command_ready,

        open_bank_valid_o => open_bank_valid,
        open_bank_o => open_bank,
        open_bank_row_o => open_bank_row,

        ca_command_o => ca_command
    );

--     direction <= DIR_WRITE;


    -- Write commands
    process
        procedure write_one(
            bank : unsigned; row : unsigned; column : unsigned;
            command : ca_command_t; precharge : std_ulogic) is
        begin
            write_request <= (
                bank => bank, row => row,
                command => command, precharge => precharge,
                valid => '1');
            loop
                clk_wait;
                exit when write_request_ready;
            end loop;
            write_request.valid <= '0';
        end;

        procedure write(
            bank : unsigned; row : unsigned; column : unsigned;
            precharge : std_ulogic := '0'; extra : natural := 0)
        is
            variable command : ca_command_t;
        begin
            case extra is
                when 0 => command := SG_WOM(bank, column);
                when 1 => command := SG_WDM(bank, column, "1111");
                when 2 => command := SG_WSM(bank, column, "1111");
                when others =>
            end case;
            write_request_extra <= to_std_ulogic(extra > 0);
            write_one(bank, row, column, command, precharge);

            -- Send any mask commands straight after
            for n in extra downto 1 loop
                command := SG_write_mask(X"ABCD");
                write_request_extra <= to_std_ulogic(n > 1);
                write_one(bank, row, column, command, precharge);
            end loop;
        end;

    begin
        write_request <= invalid_core_request;
        write_request_extra <= '0';

        clk_wait(5);
        write(X"3", 14X"1234", 7X"78");
        clk_wait;
        write(X"3", 14X"1234", 7X"79", extra => 1);
        write(X"3", 14X"1234", 7X"7A", extra => 2);
        write(X"3", 14X"1234", 7X"12");
        write(X"3", 14X"1234", 7X"13");
        write(X"3", 14X"1234", 7X"00");

        wait;
    end process;


    -- Read commands
    process
        procedure read(
            bank : unsigned; row : unsigned; column : unsigned;
            precharge : std_ulogic := '0') is
        begin
            read_request <= (
                bank => bank, row => row,
                command => SG_RD(bank, column), precharge => precharge,
                valid => '1');
            loop
                clk_wait;
                exit when read_request_ready;
            end loop;
            read_request.valid <= '0';
        end;

    begin
        read_request <= invalid_core_request;

        clk_wait(5);
        read(X"3", 14X"1234", 7X"78");
        read(X"3", 14X"1234", 7X"12");
        read(X"3", 14X"1234", 7X"00");

        wait;
    end process;


    -- Admin commands
    process
        procedure admin(count : natural) is
        begin
            admin_command <= SG_ACT(X"F", to_unsigned(count, 14));
            admin_command_valid <= '1';
            loop
                clk_wait;
                exit when admin_command_ready;
            end loop;
            admin_command_valid <= '0';
        end;

    begin
        admin_command_valid <= '0';

--         clk_wait(5);
--         for n in 1 to 10 loop
--             admin(n);
--         end loop;

        wait;
    end process;

--     process begin
--         direction <= DIR_WRITE;
--         clk_wait(
--         wait;
--     end process;


    -- Bank management.  For the moment, just open the bank on request
    process (clk)
        variable bank : integer range 0 to 15;
    begin
        if rising_edge(clk) then
            case direction is
                when DIR_READ => direction <= DIR_WRITE;
                when DIR_WRITE => direction <= DIR_READ;
            end case;

            if open_bank_valid then
                bank := to_integer(open_bank);
                bank_status.active(bank) <= '1';
                bank_status.rows(bank) <= open_bank_row;
                bank_status.read_ready(bank) <= '1';
                bank_status.write_ready(bank) <= '1';
            end if;
            tick_count <= tick_count + 1;
        end if;
    end process;


    -- Decode CA commands and print
    decode : entity work.decode_commands port map (
        clk_i => clk,
        ca_command_i => ca_command
    );
end;
