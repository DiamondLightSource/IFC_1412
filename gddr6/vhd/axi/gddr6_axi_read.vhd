-- AXI interface for reading data

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_axi_defs.all;

entity gddr6_axi_read is
    generic (
        DATA_FIFO_BITS : natural;
        COMMAND_FIFO_BITS : natural;
        MAX_DELAY : real := 4.0
    );
    port (
        -- AXI interface
        axi_clk_i : in std_ulogic;
        -- RA
        axi_address_i : in axi_address_t;
        axi_address_ready_o : out std_ulogic;
        -- R
        axi_data_o : out axi_read_data_t;
        axi_data_ready_i : in std_ulogic;

        -- CTRL interface
        ctrl_clk_i : in std_ulogic;
        ctrl_request_o : out axi_ctrl_read_request_t;
        ctrl_response_i : in axi_ctrl_read_response_t;

        -- Stats
        stats_o : out raw_stats_t
    );
end;

architecture arch of gddr6_axi_read is
    signal address_command : burst_command_t;
    signal address_command_ready : std_ulogic;
    signal data_command : burst_command_t;
    signal data_command_ready : std_ulogic;

    signal axi_data : read_data_t;
    signal axi_data_ready : std_ulogic;
    signal axi_address : address_t;
    signal axi_address_ready : std_ulogic;
    signal ctrl_address : address_t;
    signal ctrl_address_ready : std_ulogic;
    signal ctrl_reserve_valid : std_ulogic;
    signal ctrl_reserve_ready : std_ulogic;

begin
    -- -------------------------------------------------------------------------
    -- AXI protocol

    address : entity work.gddr6_axi_address port map (
        clk_i => axi_clk_i,

        axi_address_i => axi_address_i,
        axi_ready_o => axi_address_ready_o,

        command_o => address_command,
        command_ready_i => address_command_ready,

        ctrl_address_o => axi_address,
        ctrl_ready_i => axi_address_ready,

        stats_frame_error_o => stats_o.frame_error,
        stats_address_o => stats_o.address
    );

    command_fifo : entity work.gddr6_axi_command_fifo generic map (
        COMMAND_FIFO_BITS => COMMAND_FIFO_BITS
    ) port map (
        clk_i => axi_clk_i,

        command_i => address_command,
        ready_o => address_command_ready,

        command_o => data_command,
        ready_i => data_command_ready
    );

    data : entity work.gddr6_axi_read_data port map (
        clk_i => axi_clk_i,

        command_i => data_command,
        command_ready_o => data_command_ready,

        fifo_data_i => axi_data,
        fifo_data_ready_o => axi_data_ready,

        axi_data_o => axi_data_o,
        axi_ready_i => axi_data_ready_i,

        stats_crc_error_o => stats_o.crc_error,
        stats_transfer_o => stats_o.transfer,
        stats_data_beat_o => stats_o.data_beat
    );

    -- Unused stats, only valid for write
    stats_o.last_error <= '0';


    -- -------------------------------------------------------------------------
    -- Clock domain crossing FIFOs

    address_fifo : entity work.gddr6_axi_address_fifo generic map (
        COMMAND_FIFO_BITS => COMMAND_FIFO_BITS,
        MAX_DELAY => MAX_DELAY
    ) port map (
        axi_clk_i => axi_clk_i,
        axi_address_i => axi_address,
        axi_ready_o => axi_address_ready,

        ctrl_clk_i => ctrl_clk_i,
        ctrl_address_o => ctrl_address,
        ctrl_ready_i => ctrl_address_ready
    );

    data_fifo : entity work.gddr6_axi_read_data_fifo generic map (
        DATA_FIFO_BITS => DATA_FIFO_BITS,
        MAX_DELAY => MAX_DELAY
    ) port map (
        axi_clk_i => axi_clk_i,

        axi_data_o => axi_data,
        axi_ready_i => axi_data_ready,

        ctrl_clk_i => ctrl_clk_i,

        ctrl_reserve_valid_o => ctrl_reserve_valid,
        ctrl_reserve_ready_i => ctrl_reserve_ready,

        ctrl_data_i => ctrl_response_i.rd_data,
        ctrl_data_valid_i => ctrl_response_i.rd_valid,
        ctrl_data_ok_i => ctrl_response_i.rd_ok,
        ctrl_data_ok_valid_i => ctrl_response_i.rd_ok_valid
    );


    -- -------------------------------------------------------------------------
    -- CTRL interface (data connection is direct to data FIFO)

    ctrl : entity work.gddr6_axi_ctrl port map (
        clk_i => ctrl_clk_i,

        address_i => ctrl_address,
        address_ready_o => ctrl_address_ready,

        reserve_valid_i => ctrl_reserve_valid,
        reserve_ready_o => ctrl_reserve_ready,

        ctrl_address_o => ctrl_request_o.ra_address,
        ctrl_valid_o => ctrl_request_o.ra_valid,
        ctrl_ready_i => ctrl_response_i.ra_ready,
        lookahead_address_o => ctrl_request_o.ral_address,
        lookahead_count_o => ctrl_request_o.ral_count,
        lookahead_valid_o => ctrl_request_o.ral_valid
    );
end;
