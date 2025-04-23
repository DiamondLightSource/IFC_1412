library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

use work.gddr6_ctrl_defs.all;
-- use work.gddr6_defs.all;

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

    signal axi_address : unsigned(24 downto 0);
    signal axi_byte_mask : std_ulogic_vector(127 downto 0);
    signal axi_valid : std_ulogic;
    signal axi_ready : std_ulogic;
    signal write_request : core_request_t;
    signal write_ready : std_ulogic;

    signal request_delay : natural := 0;
    signal request_counter : natural := 0;

    signal tick_count : natural;

    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

begin
    clk <= not clk after 2 ns;

    write_inst : entity work.gddr6_ctrl_write port map (
        clk_i => clk,
        axi_address_i => axi_address,
        axi_byte_mask_i => axi_byte_mask,
        axi_valid_i => axi_valid,
        axi_ready_o => axi_ready,
        write_request_o => write_request,
        write_ready_i => write_ready
    );

    -- AXI producer
    process
        variable address : natural := 0;

        procedure write(
            byte_mask : std_ulogic_vector(127 downto 0) := (others => '1')) is
        begin
            axi_address <= to_unsigned(address, 25);
            axi_byte_mask <= byte_mask;
            axi_valid <= '1';
            loop
                clk_wait;
                exit when axi_ready;
            end loop;
            axi_address <= (others => 'U');
            axi_byte_mask <= (others => 'U');
            axi_valid <= '0';

            address := address + 1;
        end;

        -- Some simple byte mask patterns
        constant NOP : std_ulogic_vector(31 downto 0) := X"0000_0000";
        constant WOM : std_ulogic_vector(31 downto 0) := X"FFFF_FFFF";
        -- Corresponding WDM mask is: D81B
        constant WDM : std_ulogic_vector(31 downto 0) := X"F3C0_03CF";
        -- Corresponding WSM mask is: 46EC (even), 1416 (odd)
        constant WSM : std_ulogic_vector(31 downto 0) := X"1234_5678";

    begin
        axi_valid <= '0';
        clk_wait(2);

        request_delay <= 0;
        write(string'("Writes without delays"));
        write(NOP & NOP & WOM & WDM);
        write;
        write(NOP & NOP & NOP & WSM);
        write;
        write;
        write(WOM & WOM & WDM & WSM);
        write(NOP & NOP & NOP & NOP);
        write(WSM & WSM & WSM & WSM);
        write(WDM & WDM & WDM & WDM);
        write;

        write(string'("Writes with write delays"));
        clk_wait(2);
        write(NOP & NOP & WOM & WDM);
        clk_wait(2);
        write;
        clk_wait(2);
        write(NOP & NOP & NOP & WSM);
        clk_wait(2);
        write;
        clk_wait(2);
        write;
        clk_wait(2);
        write(WOM & WOM & WDM & WSM);
        clk_wait(2);
        write(NOP & NOP & NOP & NOP);
        clk_wait(2);
        write(WSM & WSM & WSM & WSM);
        clk_wait(2);
        write(WDM & WDM & WDM & WDM);
        clk_wait(2);
        write;

        write(string'("Adjusting ack delay"));
        clk_wait(5);

        request_delay <= 2;
        write(NOP & NOP & WOM & WDM);
        write;
        write(NOP & NOP & NOP & WSM);
        write;
        write;
        write(WOM & WOM & WDM & WSM);
        write(NOP & NOP & NOP & NOP);
        write(WSM & WSM & WSM & WSM);
        write(WDM & WDM & WDM & WDM);
        write;

        write(string'("All writes done"));

        wait;
    end process;

    -- Validate expected results
    process
        variable address : natural := 0;

        procedure wait_for_request is
        begin
            loop
                clk_wait;
                exit when write_request.valid and write_ready;
            end loop;
        end;

        impure function get_opcode return std_ulogic_vector
        is
            variable ca : vector_array(0 to 1)(9 downto 0);
        begin
            ca := write_request.command.ca;
            return ca(0)(9 downto 8) & ca(1)(9 downto 6);
        end;

        impure function get_enables return std_ulogic_vector is
        begin
            return write_request.command.ca3;
        end;

        impure function get_column return natural
        is
            variable ca : vector_array(0 to 1)(9 downto 0);
        begin
            ca := write_request.command.ca;
            return to_integer(unsigned(
                std_ulogic_vector'(ca(1)(2 downto 0) & ca(0)(3 downto 0))));
        end;

        impure function get_mask return std_ulogic_vector
        is
            variable ca : vector_array(0 to 1)(9 downto 0);
        begin
            ca := write_request.command.ca;
            assert ca(0)(9 downto 8) & ca(1)(9 downto 8) = "1111"
                report "This is not a mask!"
                severity failure;
            return ca(1)(7 downto 0) & ca(0)(7 downto 0);
        end;

        procedure expect(
            opcode : std_ulogic_vector;
            enables : std_ulogic_vector := "1111";
            advance : std_ulogic := '1') is
        begin
            wait_for_request;
            assert opcode = get_opcode
                report "Invalid opcode: " &
                    to_hstring(opcode) & " /= " & to_hstring(get_opcode)
                severity failure;
            assert enables = get_enables
                report "Invalid enables: " &
                    to_string(enables) & " /= " & to_string(get_enables)
                severity failure;
            assert address = get_column
                report "Invalid address: " &
                    to_string(address) & " /= " & to_string(get_column)
                severity failure;
            assert advance = write_request.write_advance
                report "Inconsisted advance state"
                severity failure;
            if advance then
                address := address + 1;
            end if;
        end;

        procedure expect_mask(mask : std_ulogic_vector) is
        begin
            wait_for_request;
            assert write_request.extra
                report "Expected mask got command"
                severity failure;
            assert get_mask = mask
                report "Invalid mask value: expected " &
                    to_hstring(mask) & " but read " & to_hstring(get_mask)
                severity failure;
        end;

        -- Expected opcodes
        constant WOM : std_ulogic_vector(5 downto 0) := "110000";
        constant WDM : std_ulogic_vector(5 downto 0) := "110010";
        constant WSM : std_ulogic_vector(5 downto 0) := "110001";

        -- Expected masks
        constant WDM_MASK : std_ulogic_vector(15 downto 0) := not X"D81B";
        constant WSM_MASK1 : std_ulogic_vector(15 downto 0) := not X"46EC";
        constant WSM_MASK2 : std_ulogic_vector(15 downto 0) := not X"1416";

    begin
        for i in 0 to 2 loop
            write("Checking loop " & to_string(i));

            -- write(NOP & NOP & WOM & WDM)
            expect(WOM, "0100", '0');
            expect(WDM, "1000");
            expect_mask(WDM_MASK);
            -- write
            expect(WOM);
            -- write(NOP & NOP & NOP & WSM)
            expect(WSM, "1000");
            expect_mask(WSM_MASK1);
            expect_mask(WSM_MASK2);
            -- write x2
            expect(WOM);
            expect(WOM);
            -- write(WOM & WOM & WDM & WSM);
            expect(WOM, "0011", '0');
            expect(WDM, "0100", '0');
            expect_mask(WDM_MASK);
            expect(WSM, "1000");
            expect_mask(WSM_MASK1);
            expect_mask(WSM_MASK2);
            -- write(NOP & NOP & NOP & NOP);
            expect(WOM, "0000");
            -- write(WSM & WSM & WSM & WSM);
            expect(WSM, "0001", '0');
            expect_mask(WSM_MASK1);
            expect_mask(WSM_MASK2);
            expect(WSM, "0010", '0');
            expect_mask(WSM_MASK1);
            expect_mask(WSM_MASK2);
            expect(WSM, "0100", '0');
            expect_mask(WSM_MASK1);
            expect_mask(WSM_MASK2);
            expect(WSM, "1000");
            expect_mask(WSM_MASK1);
            expect_mask(WSM_MASK2);
            -- write(WDM & WDM & WDM & WDM);
            expect(WDM, "0001", '0');
            expect_mask(WDM_MASK);
            expect(WDM, "0010", '0');
            expect_mask(WDM_MASK);
            expect(WDM, "0100", '0');
            expect_mask(WDM_MASK);
            expect(WDM, "1000");
            expect_mask(WDM_MASK);
            -- write
            expect(WOM);
        end loop;

        write("Expects complete");

        wait;
    end process;


    -- Request acknowledge after configurable delay
    process (clk) begin
        if rising_edge(clk) then
            if request_counter > 0 and write_request.valid = '1' then
                request_counter <= request_counter - 1;
            else
                request_counter <= request_delay;
            end if;
        end if;
    end process;
    write_ready <= to_std_ulogic(request_counter = 0);


    decode : entity work.decode_commands generic map (
        REPORT_NOP => true,
        ONLY_VALID => true
    ) port map (
        clk_i => clk,
        valid_i => write_request.valid and write_ready,
        ca_command_i => write_request.command,
        tick_count_o => tick_count
    );
end;
