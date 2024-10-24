-- Memory controller core
--
-- Entity structure:
--
--  gddr6_ctrl
--      gddr6_ctrl_read             Generate SG read commands
--      gddr6_ctrl_write            Generate SG write commands
--      gddr6_ctrl_lookahead        Generate bank open request from lookahead
--      gddr6_ctrl_refresh          Refresh controller
--      gddr6_ctrl_command          Command dispatcher and bank management
--          gddr6_ctrl_banks            State and timing control for all banks
--              gddr6_ctrl_bank             One bank state and timing
--          gddr6_ctrl_mux              Read/Write command multiplexer
--          gddr6_ctrl_request          Command timing and bank handshake
--          gddr6_ctrl_admin            Generate bank administration commands
--      gddr6_ctrl_data             Read and write data handling
--          fixed_delay

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_ctrl_timing_defs.all;
use work.gddr6_ctrl_command_defs.all;
use work.gddr6_ctrl_defs.all;

entity gddr6_ctrl is
    generic (
        -- These are designed to be overwritten to speed up simulation only
        SHORT_REFRESH_COUNT : natural := t_REFI;
        LONG_REFRESH_COUNT : natural := t_ABREF_REFI
    );
    port (
        clk_i : in std_ulogic;

        -- Configuration and setup control
        ctrl_setup_i : in ctrl_setup_t;
        temperature_o : out sg_temperature_t;

        -- Connection from AXI receiver
        axi_read_request_i : in axi_ctrl_read_request_t;
        axi_read_response_o : out axi_ctrl_read_response_t;
        axi_write_request_i : in axi_ctrl_write_request_t;
        axi_write_response_o : out axi_ctrl_write_response_t;

        -- Connection to PHY (via Setup MUX)
        phy_ca_o : out phy_ca_t;
        phy_dq_o : out phy_dq_out_t;
        phy_dq_i : in phy_dq_in_t
    );
end;

architecture arch of gddr6_ctrl is
    signal read_request : core_request_t;
    signal read_ready : std_ulogic;
    signal write_request : core_request_t;
    signal write_ready : std_ulogic;
    signal request_completion : request_completion_t;

    signal open_lookahead : bank_open_t;

    signal banks_status : banks_status_t;
    signal priority_direction : direction_t;
    signal current_direction : direction_t;
    signal refresh_command : refresh_request_t;
    signal refresh_ack : std_ulogic;
    signal stall_requests : std_ulogic;

    signal refresh_start : std_ulogic;
    signal bypass_command : ca_command_t;
    signal bypass_valid : std_ulogic;

begin
    -- Generate read requests from AXI addresses
    read : entity work.gddr6_ctrl_read port map (
        clk_i => clk_i,

        axi_address_i => axi_read_request_i.ra_address,
        axi_valid_i => axi_read_request_i.ra_valid,
        axi_ready_o => axi_read_response_o.ra_ready,

        read_request_o => read_request,
        read_ready_i => read_ready
    );

    -- Generate write requests.  This is more involved as a non trivial byte
    -- mask may entail generating multiple write requests in response to a
    -- single AXI address
    write : entity work.gddr6_ctrl_write port map (
        clk_i => clk_i,

        axi_address_i => axi_write_request_i.wa_address,
        axi_byte_mask_i => axi_write_request_i.wa_byte_mask,
        axi_valid_i => axi_write_request_i.wa_valid,
        axi_ready_o => axi_write_response_o.wa_ready,

        write_request_o => write_request,
        write_ready_i => write_ready
    );

    -- Inspect AXI lookahead requests and pass one through as appropriate.  This
    -- can be an important optimisation for streaming data, but needs to be
    -- carefully managed to avoid generating conflicting bank requests.
    lookahead : entity work.gddr6_ctrl_lookahead port map (
        clk_i => clk_i,

        ral_address_i => axi_read_request_i.ral_address,
        ral_count_i => axi_read_request_i.ral_count,
        ral_valid_i => axi_read_request_i.ral_valid,
        wal_address_i => axi_write_request_i.wal_address,
        wal_count_i => axi_write_request_i.wal_count,
        wal_valid_i => axi_write_request_i.wal_valid,

        status_i => banks_status,
        direction_i => current_direction,

        lookahead_o => open_lookahead
    );

    -- Autonomous refresh generator.  Generates refresh requests as required.
    refresh : entity work.gddr6_ctrl_refresh generic map (
        SHORT_REFRESH_COUNT => SHORT_REFRESH_COUNT,
        LONG_REFRESH_COUNT => LONG_REFRESH_COUNT
    ) port map (
        clk_i => clk_i,

        status_i => banks_status,
        enable_refresh_i => ctrl_setup_i.enable_refresh,
        stall_requests_o => stall_requests,
        refresh_request_o => refresh_command,
        refresh_ack_i => refresh_ack
    );

    -- Command dispatch including timing control and bank management.  Takes as
    -- input a stream of read and write requests together with admin requests,
    -- works with bank status management to ensure that memory timing is
    -- respected and that the correct command is sent to the correct bank in the
    -- appropriate state.
    with ctrl_setup_i.priority_direction select
        priority_direction <= DIR_WRITE when '1', DIR_READ when others;
    command : entity work.gddr6_ctrl_command port map (
        clk_i => clk_i,

        write_request_i => write_request,
        write_request_ready_o => write_ready,
        read_request_i => read_request,
        read_request_ready_o => read_ready,
        request_completion_o => request_completion,

        lookahead_i => open_lookahead,
        refresh_i => refresh_command,
        refresh_ack_o => refresh_ack,

        refresh_start_o => refresh_start,
        bypass_command_i => bypass_command,
        bypass_valid_i => bypass_valid,

        enable_mux_i => ctrl_setup_i.enable_axi and not stall_requests,
        priority_mode_i => ctrl_setup_i.priority_mode,
        priority_direction_i => priority_direction,
        current_direction_o => current_direction,

        banks_status_o => banks_status,

        ca_command_o.ca => phy_ca_o.ca,
        ca_command_o.ca3 => phy_ca_o.ca3
    );
    phy_ca_o.cke_n <= '0';


    temps : entity work.gddr6_ctrl_temps port map (
        clk_i => clk_i,

        refresh_start_i => refresh_start,
        command_o => bypass_command,
        command_valid_o => bypass_valid,
        data_i => phy_dq_i.data,

        temperature_o => temperature_o
    );

    -- Manages data timing and EDC checking
    data : entity work.gddr6_ctrl_data port map (
        clk_i => clk_i,

        request_completion_i => request_completion,

        output_enable_o => phy_dq_o.output_enable,

        phy_data_i => phy_dq_i.data,
        phy_data_o => phy_dq_o.data,

        edc_in_i => phy_dq_i.edc_in,
        edc_read_i => phy_dq_i.edc_read,
        edc_write_i => phy_dq_i.edc_write,

        axi_rd_data_o => axi_read_response_o.rd_data,
        axi_rd_valid_o => axi_read_response_o.rd_valid,
        axi_rd_ok_o => axi_read_response_o.rd_ok,
        axi_rd_ok_valid_o => axi_read_response_o.rd_ok_valid,

        axi_wd_data_i => axi_write_request_i.wd_data,
        axi_wd_advance_o => axi_write_response_o.wd_advance,
        axi_wd_ready_o => axi_write_response_o.wd_ready,
        axi_wr_ok_o => axi_write_response_o.wr_ok,
        axi_wr_ok_valid_o => axi_write_response_o.wr_ok_valid
    );
end;
