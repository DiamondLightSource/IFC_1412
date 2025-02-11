library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.register_defs.all;
use work.gddr6_defs.all;

use work.register_defines.all;
use work.sim_support.all;

entity testbench is
end testbench;


architecture arch of testbench is
    signal clk : std_ulogic := '0';

    procedure clk_wait(count : natural := 1) is
    begin
        clk_wait(clk, count);
    end;


    signal write_strobe : std_ulogic_vector(AXI_REGS_RANGE) := (others => '0');
    signal write_data : reg_data_array_t(AXI_REGS_RANGE);
    signal write_ack : std_ulogic_vector(AXI_REGS_RANGE);
    signal read_strobe : std_ulogic_vector(AXI_REGS_RANGE) := (others => '0');
    signal read_data : reg_data_array_t(AXI_REGS_RANGE);
    signal read_ack : std_ulogic_vector(AXI_REGS_RANGE);

    signal capture_trigger : std_ulogic;

    signal axi_request : axi_request_t := IDLE_AXI_REQUEST;
    signal axi_response : axi_response_t := (
        write_address_ready => '1',
        write_data_ready => '1',
        write_response => IDLE_AXI_WRITE_RESPONSE,
        read_address_ready => '0',
        read_data => IDLE_AXI_READ_DATA
    );
    signal axi_stats : std_ulogic_vector(0 to 10) := (others => '0');

begin
    clk <= not clk after 2 ns;

    axi : entity work.axi port map (
        clk_i => clk,

        write_strobe_i => write_strobe,
        write_data_i => write_data,
        write_ack_o => write_ack,
        read_strobe_i => read_strobe,
        read_data_o => read_data,
        read_ack_o => read_ack,

        capture_trigger_o => capture_trigger,

        axi_request_o => axi_request,
        axi_response_i => axi_response,
        axi_stats_i => axi_stats
    );


    -- Drive the register interface
    process
        procedure write_reg(
            reg : natural; value : reg_data_t; quiet : boolean := false) is
        begin
            write_reg(
                clk, write_data, write_strobe, write_ack, reg, value, quiet);
        end;

        procedure read_reg(reg : natural) is
        begin
            read_reg(clk, read_data, read_strobe, read_ack, reg);
        end;

    begin
        -- Start writing
        write_reg(AXI_COMMAND_REG_W, (
            AXI_COMMAND_START_WRITE_BIT => '1',
            others => '0'));
        -- Fill the write buffer
        for i in 1 to 64 loop
            write_reg(AXI_SETUP_REG, (
                AXI_SETUP_BYTE_MASK_BITS => "1111",
                others => '0'), true);
            write_reg(AXI_DATA_REG,
                X"1234_FE" & to_std_ulogic_vector_u(i, 8), true);
            write_reg(AXI_COMMAND_REG_W, (
                AXI_COMMAND_STEP_WRITE_BIT => '1',
                others => '0'), true);
        end loop;
        -- Trigger the transaction
        write_reg(AXI_COMMAND_REG_W, (
            AXI_COMMAND_START_AXI_WRITE_BIT => '1',
            others => '0'));

        wait;
    end process;


--     -- Dummy AXI interface
--     process (clk) begin
--         if rising_edge(clk) then
--             if axi_request.write_address.valid then
--         end if;
--     end process;
end;
