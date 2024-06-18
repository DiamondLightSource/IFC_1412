-- AXI interface for writing data

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_axi_defs.all;

entity gddr6_axi_write is
    generic (
        -- This can be overridden for simulation, but the natural depth to use
        -- is 1K as this matches the natural block RAM depth
        FIFO_BITS : natural := 10
    );
    port (
        -- AXI interface
        axi_clk_i : in std_ulogic;
        -- WA
        axi_address_i : in axi_address_t;
        axi_address_ready_o : out std_ulogic;
        -- W
        axi_data_i : in axi_write_data_t;
        axi_data_ready_o : out std_ulogic;
        -- B
        axi_response_o : out axi_write_response_t;
        axi_response_ready_i : in std_ulogic;

        -- CTRL interface
        ctrl_clk_i : in std_ulogic;
        ctrl_request_o : out axi_ctrl_write_request_t;
        ctrl_response_i : in axi_ctrl_write_response_t
    );
end;

architecture arch of gddr6_axi_write is
    -- address -> command_fifo -> write_data
    signal address_command : burst_command_t;
    signal address_command_ready : std_ulogic;
    signal command : burst_command_t;
    signal command_ready : std_ulogic;
    -- address -> response_fifo -> write_response
    signal address_response : burst_response_t;
    signal address_response_ready : std_ulogic;
    signal write_response : burst_response_t;
    signal write_response_ready : std_ulogic;
    -- address -> address_fifo -> write_ctrl
    signal axi_address : address_t;
    signal axi_address_ready : std_ulogic;
    signal ctrl_address : address_t;
    signal ctrl_address_ready : std_ulogic;

    -- write_data -> write_data_fifo -> ctrl
    signal axi_data : write_data_t;
    signal axi_data_ready : std_ulogic;
    signal ctrl_byte_mask : std_ulogic_vector(127 downto 0);
    signal ctrl_byte_mask_valid : std_ulogic;
    signal ctrl_byte_mask_ready : std_ulogic;

    -- write_response <- status_fifo -> ctrl
    signal axi_ok : std_ulogic;
    signal axi_ok_valid : std_ulogic;
    signal axi_ok_ready : std_ulogic;
    signal ctrl_reserve : std_ulogic;
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

        response_o => address_response,
        response_ready_i => address_response_ready,

        ctrl_address_o => axi_address,
        ctrl_ready_i => axi_address_ready
    );


    command_fifo : entity work.gddr6_axi_command_fifo generic map (
        FIFO_BITS => FIFO_BITS
    ) port map (
        clk_i => axi_clk_i,

        command_i => address_command,
        ready_o => address_command_ready,

        command_o => command,
        ready_i => command_ready
    );


    data : entity work.gddr6_axi_write_data port map (
        clk_i => axi_clk_i,

        fifo_command_i => command,
        fifo_ready_o => command_ready,

        fifo_data_o => axi_data,
        fifo_ready_i => axi_data_ready,

        axi_data_i => axi_data_i,
        axi_ready_o => axi_data_ready_o
    );


    response_fifo : entity work.gddr6_axi_write_response_fifo generic map (
        FIFO_BITS => FIFO_BITS
    ) port map (
        clk_i => axi_clk_i,

        response_i => address_response,
        ready_o => address_response_ready,

        response_o => write_response,
        ready_i => write_response_ready
    );

    response : entity work.gddr6_axi_write_response port map (
        clk_i => axi_clk_i,

        response_i => write_response,
        response_ready_o => write_response_ready,

        data_ok_i => axi_ok,
        data_ok_valid_i => axi_ok_valid,
        data_ok_ready_o => axi_ok_ready,

        axi_response_o => axi_response_o,
        axi_ready_i => axi_response_ready_i
    );


    -- -------------------------------------------------------------------------
    -- Clock domain crossing FIFOs

    address_fifo : entity work.gddr6_axi_address_fifo generic map (
        FIFO_BITS => FIFO_BITS
    ) port map (
        axi_clk_i => axi_clk_i,
        axi_address_i => axi_address,
        axi_ready_o => axi_address_ready,

        ctrl_clk_i => ctrl_clk_i,
        ctrl_address_o => ctrl_address,
        ctrl_ready_i => ctrl_address_ready
    );

    data_fifo : entity work.gddr6_axi_write_data_fifo generic map (
        FIFO_BITS => FIFO_BITS
    ) port map (
        axi_clk_i => axi_clk_i,
        axi_write_i => axi_data,
        axi_ready_o => axi_data_ready,

        ctrl_clk_i => ctrl_clk_i,
        ctrl_byte_mask_o => ctrl_byte_mask,
        ctrl_byte_mask_valid_o => ctrl_byte_mask_valid,
        ctrl_byte_mask_ready_i => ctrl_byte_mask_ready,
        ctrl_data_o => ctrl_request_o.wd_data,
        ctrl_data_advance_i => ctrl_response_i.wd_advance,
        ctrl_data_ready_i => ctrl_response_i.wd_ready
    );

    status_fifo : entity work.gddr6_axi_write_status_fifo generic map (
        FIFO_BITS => FIFO_BITS
    ) port map (
        axi_clk_i => axi_clk_i,
        axi_ok_o => axi_ok,
        axi_ok_valid_o => axi_ok_valid,
        axi_ok_ready_i => axi_ok_ready,

        ctrl_clk_i => ctrl_clk_i,
        ctrl_reserve_i => ctrl_reserve,
        ctrl_reserve_ready_o => ctrl_reserve_ready,
        ctrl_ok_i => ctrl_response_i.wr_ok,
        ctrl_ok_valid_i => ctrl_response_i.wr_ok_valid
    );


    -- -------------------------------------------------------------------------
    -- CTRL interface (data connection is direct to data FIFO)

    ctrl : entity work.gddr6_axi_ctrl port map (
        clk_i => ctrl_clk_i,

        address_i => ctrl_address,
        address_ready_o => ctrl_address_ready,

        byte_mask_i => ctrl_byte_mask,
        byte_mask_valid_i => ctrl_byte_mask_valid,
        byte_mask_ready_o => ctrl_byte_mask_ready,

        reserve_o => ctrl_reserve,
        reserve_ready_i => ctrl_reserve_ready,

        ctrl_address_o => ctrl_request_o.wa_address,
        ctrl_byte_mask_o => ctrl_request_o.wa_byte_mask,
        ctrl_valid_o => ctrl_request_o.wa_valid,
        ctrl_ready_i => ctrl_response_i.wa_ready,

        lookahead_address_o => ctrl_request_o.wal_address,
        lookahead_count_o => ctrl_request_o.wal_count,
        lookahead_valid_o => ctrl_request_o.wal_valid
    );
end;
