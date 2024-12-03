-- Bridge between AXI and core controller
--
-- Entity structure:
--
--  gddr6_axi
--      gddr6_axi_read                      Process AXI Read transactions
--          gddr6_axi_address               Process RA requests
--          gddr6_axi_address_fifo          FIFO for SG commands
--              async_fifo                  Cross clocks FIFO
--          gddr6_axi_command_fifo          FIFO for AXI burst control
--              fifo                        Synchronous FIFO
--          gddr6_axi_ctrl                  Sends SG request to CTRL
--          gddr6_axi_read_data_fifo        FIFO for read data from CTRL
--              async_fifo_address          Cross clocks FIFO address control
--              memory_array_dual           Dual port BRAM for data FIFO
--          gddr6_axi_read_data             Process R bursts
--      gddr6_axi_write                     Process AXI Write transactions
--          gddr6_axi_address               Process WA requests
--          gddr6_axi_address_fifo          (as above)
--          gddr6_axi_command_fifo          (as above)
--          gddr6_axi_ctrl                  (as above)
--          gddr6_axi_write_data            Process W bursts
--          gddr6_axi_write_data_fifo       FIFO for write data to CTRL
--              async_fifo
--              async_fifo_address
--              memory_array_dual_bytes
--          gddr6_axi_write_response_fifo   FIFO for B request control
--              fifo
--          gddr6_axi_write_status_fifo     FIFO for write completion status
--              async_fifo_address
--              memory_array_dual
--          gddr6_axi_write_response        Process B requests on write complete

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gddr6_defs.all;
use work.gddr6_axi_defs.all;

entity gddr6_axi is
    generic (
        -- Used to compute the appropriate constraints for the clock domain
        -- crossing FIFOs
        AXI_FREQUENCY : real := 250.0;
        CK_FREQUENCY : real := 250.0;

        -- This can be overridden for simulation, but the natural depth to use
        -- is 1K as this matches the natural block RAM depth.  Note that this
        -- determines the number of SG bursts supported by each data FIFO
        DATA_FIFO_BITS : natural := 10;
        -- Command FIFOs can be shallower, and 64 is a natural dist RAM depth
        COMMAND_FIFO_BITS : natural := 6
    );
    port (
        -- The AXI slave interface is on axi_clk_i and is bridged within this
        -- component to the SG controller on ck_clk_i
        axi_clk_i : in std_ulogic;

        axi_request_i : in axi_request_t;
        axi_response_o : out axi_response_t;
        axi_stats_o : out axi_stats_t;

        -- ---------------------------------------------------------------------
        -- Controller interface on CK clk

        ck_clk_i : in std_ulogic;

        -- Connection to CTRL
        ctrl_read_request_o : out axi_ctrl_read_request_t;
        ctrl_read_response_i : in axi_ctrl_read_response_t;
        ctrl_write_request_o : out axi_ctrl_write_request_t;
        ctrl_write_response_i : in axi_ctrl_write_response_t
    );
end;

architecture arch of gddr6_axi is
    -- For correct behaviour the clock domain crossing FIFOs need to be
    -- constrained by the maximum clock frequency.
    constant MAX_DELAY : real := 1000.0 / maximum(AXI_FREQUENCY, CK_FREQUENCY);

    signal write_stats : raw_stats_t;
    signal read_stats : raw_stats_t;

begin
    axi_write : entity work.gddr6_axi_write generic map (
        DATA_FIFO_BITS => DATA_FIFO_BITS,
        COMMAND_FIFO_BITS => COMMAND_FIFO_BITS,
        MAX_DELAY => MAX_DELAY
    ) port map (
        axi_clk_i => axi_clk_i,

        axi_address_i => axi_request_i.write_address,
        axi_address_ready_o => axi_response_o.write_address_ready,
        axi_data_i => axi_request_i.write_data,
        axi_data_ready_o => axi_response_o.write_data_ready,
        axi_response_o => axi_response_o.write_response,
        axi_response_ready_i => axi_request_i.write_response_ready,
        stats_o => write_stats,

        ctrl_clk_i => ck_clk_i,
        ctrl_request_o => ctrl_write_request_o,
        ctrl_response_i => ctrl_write_response_i
    );


    axi_read : entity work.gddr6_axi_read generic map (
        DATA_FIFO_BITS => DATA_FIFO_BITS,
        COMMAND_FIFO_BITS => COMMAND_FIFO_BITS,
        MAX_DELAY => MAX_DELAY
    ) port map (
        axi_clk_i => axi_clk_i,

        axi_address_i => axi_request_i.read_address,
        axi_address_ready_o => axi_response_o.read_address_ready,
        axi_data_o => axi_response_o.read_data,
        axi_data_ready_i => axi_request_i.read_data_ready,
        stats_o => read_stats,

        ctrl_clk_i => ck_clk_i,
        ctrl_request_o => ctrl_read_request_o,
        ctrl_response_i => ctrl_read_response_i
    );


    stats : entity work.gddr6_axi_stats port map (
        clk_i => axi_clk_i,
        write_stats_i => write_stats,
        read_stats_i => read_stats,
        axi_stats_o => axi_stats_o
    );
end;
