-- AXI master

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.register_defines.all;

use work.gddr6_defs.all;

entity axi is
    port (
        clk_i : in std_ulogic;

        write_strobe_i : in std_ulogic_vector(AXI_REGS_RANGE);
        write_data_i : in reg_data_array_t(AXI_REGS_RANGE);
        write_ack_o : out std_ulogic_vector(AXI_REGS_RANGE);
        read_strobe_i : in std_ulogic_vector(AXI_REGS_RANGE);
        read_data_o : out reg_data_array_t(AXI_REGS_RANGE);
        read_ack_o : out std_ulogic_vector(AXI_REGS_RANGE);

        capture_trigger_o : out std_ulogic;

        axi_request_o : out axi_request_t;
        axi_response_i : in axi_response_t;
        axi_stats_i : in std_ulogic_vector(0 to 10)
    );
end;

architecture arch of axi is
    signal status_bits : reg_data_t;
    signal command_bits : reg_data_t;
    signal config_bits : reg_data_array_t(AXI_CONFIG_REGS);
    signal request_bits : reg_data_t;
    signal setup_bits : reg_data_t;
    signal axi_stats : reg_data_array_t(0 to 10);

    -- General commands
    signal reset_stats : std_ulogic := '0';
    signal cmd_reset_stats : std_ulogic;

    -- Transaction request
    signal request_address : unsigned(25 downto 0);
    signal request_length : unsigned(5 downto 0);
    signal byte_mask : std_ulogic_vector(3 downto 0);

    -- Data read/write control bits
    signal start_read : std_ulogic;
    signal step_read : std_ulogic;
    signal start_write : std_ulogic;
    signal step_write : std_ulogic;

    signal start_axi_write : std_ulogic;
    signal start_axi_read : std_ulogic;

    -- AXI transaction control and status bits
    signal axi_out_busy : std_ulogic;
    signal axi_in_busy : std_ulogic;
    signal axi_out_count : unsigned(5 downto 0);
    signal axi_in_count : unsigned(5 downto 0);
    signal axi_out_ok : std_ulogic;
    signal axi_in_ok : std_ulogic;

begin
    -- STATUS
    read_ack_o(AXI_STATUS_REG_R) <= '1';
    read_data_o(AXI_STATUS_REG_R) <= status_bits;

    status_bits <= (
        AXI_STATUS_IN_COUNT_BITS => std_ulogic_vector(axi_in_count),
        AXI_STATUS_OUT_COUNT_BITS => std_ulogic_vector(axi_out_count),
        AXI_STATUS_WRITE_BUSY_BIT => axi_out_busy,
        AXI_STATUS_READ_BUSY_BIT => axi_in_busy,
        AXI_STATUS_WRITE_OK_BIT => axi_out_ok,
        AXI_STATUS_READ_OK_BIT => axi_in_ok,
        others => '0'
    );

    -- COMMAND
    command : entity work.register_command port map (
        clk_i => clk_i,
        write_strobe_i => write_strobe_i(AXI_COMMAND_REG_W),
        write_data_i => write_data_i(AXI_COMMAND_REG_W),
        write_ack_o => write_ack_o(AXI_COMMAND_REG_W),
        strobed_bits_o => command_bits
    );

    capture_trigger_o <= command_bits(AXI_COMMAND_CAPTURE_BIT);
    cmd_reset_stats <= command_bits(AXI_COMMAND_RESET_STATS_BIT);

    start_read <= command_bits(AXI_COMMAND_START_READ_BIT);
    step_read <= command_bits(AXI_COMMAND_STEP_READ_BIT);
    start_write <= command_bits(AXI_COMMAND_START_WRITE_BIT);
    step_write <= command_bits(AXI_COMMAND_STEP_WRITE_BIT);

    start_axi_write <= command_bits(AXI_COMMAND_START_AXI_WRITE_BIT);
    start_axi_read <= command_bits(AXI_COMMAND_START_AXI_READ_BIT);


    -- CONFIG
    request : entity work.register_file_rw port map (
        clk_i => clk_i,
        write_strobe_i => write_strobe_i(AXI_CONFIG_REGS),
        write_data_i => write_data_i(AXI_CONFIG_REGS),
        write_ack_o => write_ack_o(AXI_CONFIG_REGS),
        read_strobe_i => read_strobe_i(AXI_CONFIG_REGS),
        read_data_o => read_data_o(AXI_CONFIG_REGS),
        read_ack_o => read_ack_o(AXI_CONFIG_REGS),
        register_data_o => config_bits
    );

    request_bits <= config_bits(AXI_REQUEST_REG);
    setup_bits <= config_bits(AXI_SETUP_REG);


    -- REQUEST
    request_address <= unsigned(request_bits(AXI_REQUEST_ADDRESS_BITS));
    request_length <= unsigned(request_bits(AXI_REQUEST_LENGTH_BITS));

    -- SETUP
    byte_mask <= setup_bits(AXI_SETUP_BYTE_MASK_BITS);


    -- STATS
    write_ack_o(AXI_STATS_REGS) <= (others => '1');
    read_ack_o(AXI_STATS_REGS) <= (others => '1');
    read_data_o(AXI_STATS_REGS) <= axi_stats;

    stats : entity work.axi_stats port map (
        clk_i => clk_i,
        reset_i => cmd_reset_stats,
        axi_stats_i => axi_stats_i,
        stats_o => axi_stats
    );


    -- DATA
    data : entity work.axi_data port map (
        clk_i => clk_i,

        write_strobe_i => write_strobe_i(AXI_DATA_REG),
        write_data_i => write_data_i(AXI_DATA_REG),
        write_ack_o => write_ack_o(AXI_DATA_REG),
        read_strobe_i => read_strobe_i(AXI_DATA_REG),
        read_data_o => read_data_o(AXI_DATA_REG),
        read_ack_o => read_ack_o(AXI_DATA_REG),

        start_read_i => start_read,
        step_read_i => step_read,
        start_write_i => start_write,
        step_write_i => step_write,
        write_mask_i => byte_mask,

        axi_out_start_i => start_axi_write,
        axi_out_busy_o => axi_out_busy,
        axi_out_count_o => axi_out_count,
        axi_in_start_i => start_axi_read,
        axi_in_busy_o => axi_in_busy,
        axi_in_count_o => axi_in_count,
        axi_out_ok_o => axi_out_ok,
        axi_in_ok_o => axi_in_ok,

        axi_out_o => axi_request_o.write_data,
        axi_out_ready_i => axi_response_i.write_data_ready,
        axi_out_response_i => axi_response_i.write_response,
        axi_out_response_ready_o => axi_request_o.write_response_ready,
        axi_in_i => axi_response_i.read_data,
        axi_in_ready_o => axi_request_o.read_data_ready
    );


    address : entity work.axi_address port map (
        clk_i => clk_i,

        address_i => request_address,
        write_count_i => axi_out_count - 1,
        read_count_i => request_length,

        start_axi_write_i => start_axi_write,
        start_axi_read_i => start_axi_read,

        -- Communication to AXI
        write_address_o => axi_request_o.write_address,
        write_address_ready_i => axi_response_i.write_address_ready,
        read_address_o => axi_request_o.read_address,
        read_address_ready_i => axi_response_i.read_address_ready
    );
end;
