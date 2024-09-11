-- Bridge between AXI and core controller

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gddr6_axi is
    generic (
        -- Used to compute the appropriate constraints for the clock domain
        -- crossing FIFOs
        AXI_FREQUENCY : real := 250.0;
        CK_FREQUENCY : real := 250.0;

        -- This can be overridden for simulation, but the natural depth to use
        -- is 1K as this matches the natural block RAM depth
        DATA_FIFO_BITS : natural := 10;
        -- Command FIFOs can be shallower, and 64 is a natural dist RAM depth
        COMMAND_FIFO_BITS : natural := 6
    );
    port (
        -- The AXI slave interface is on axi_clk_i and is bridged within this
        -- component to the SG controller on ck_clk_i
        axi_clk_i : in std_ulogic;

        -- WA
        axi_wa_i : in axi_write_address_t;
        axi_wa_ready_o : out std_ulogic;
        -- W
        axi_w_i : in axi_write_data_t;
        axi_w_ready_o : out std_ulogic;
        -- B
        axi_b_o : out axi_write_response_t;
        axi_b_ready_i : in std_ulogic;
        -- RA
        axi_ra_i : in axi_read_address_t;
        axi_ra_ready_o : out std_ulogic;
        -- R
        axi_r_o : out axi_read_data_t;
        axi_r_ready_o : in std_ulogic;

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

begin
    axi_write : entity work.gddr6_axi_write generic map (
        DATA_FIFO_BITS => DATA_FIFO_BITS,
        COMMAND_FIFO_BITS => COMMAND_FIFO_BITS,
        MAX_DELAY => MAX_DELAY
    ) port map (
        axi_clk_i => axi_clk_i,
        axi_address_i => axi_wa_i,
        axi_address_ready_o => axi_wa_ready_o,
        axi_data_i => axi_w_i,
        axi_data_ready_o => axi_w_ready_o,
        axi_response_o => axi_b_o,
        axi_response_ready_i => axi_b_ready_i,

        ctrl_clk_i => ck_clk_i,
        ctrl_request_o => ctrl_write_request_o,
        ctrl_response_i => ctrl_write_response_i,
    );

    axi_read : entity work.gddr6_axi_read generic map (
        DATA_FIFO_BITS => DATA_FIFO_BITS,
        COMMAND_FIFO_BITS => COMMAND_FIFO_BITS,
        MAX_DELAY => MAX_DELAY
    ) port map (
        axi_clk_i => axi_clk_i,
        axi_address_i => axi_ra_i,
        axi_address_ready_o => axi_ra_ready_o,
        axi_data_o => axi_r_o,
        axi_data_ready_i => axi_r_ready_o,

        ctrl_clk_i => ck_clk_i,
        ctrl_request_o => ctrl_read_request_o,
        ctrl_response_i => ctrl_read_response_i,
    );
end;
