-- Delay definitions for aligning streams

-- These definitions capture the key delays between CTRL and the SG and are
-- dependent on the precise implementation of the PHY layer and the behaviour of
-- the BITSLICE components.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gddr6_ctrl_timing_defs.all;

package gddr6_ctrl_delay_defs is
    -- The following delays are measured from input to the appropriate BITSLICE
    -- input in _phy_nibble to the corresponding output.
    constant TX_BITSLICE_DELAY : natural := 3;
    constant RX_BITSLICE_DELAY : natural := 3;
    constant TRI_BITSLICE_DELAY : natural := TX_BITSLICE_DELAY + 1;


    -- These capture delays between CTRL and PHY used for SETUP multiplexing
    constant MUX_OUTPUT_DELAY : natural := 1;
    constant MUX_INPUT_DELAY : natural := 1;


    -- Delay from request_completion_i (synchronous with command_o from
    -- _ctrl_request) to SG CA input
    constant CA_OUTPUT_DELAY : natural :=
        -- CA output: _ctrl_request.command_o
        --  => _ctrl_command.ca_command_o
        --  (=> output mux)
        --  => _phy_ca.d1,d2 => ODDR => CA
        MUX_OUTPUT_DELAY + 3;

    -- Delay from output_enable_o here to output enable on edge of FPGA
    constant OE_OUTPUT_DELAY : natural :=
        -- Tristate control: _ctrl_data.output_enable_o
        --  (=> output mux)
        --  => _phy_byte.tbyte_in
        --  => BITSLICE_CONTROL => TX_BITSLICE_TRI => RXTX_BITSLICE => OE
        MUX_OUTPUT_DELAY + 1 + TRI_BITSLICE_DELAY;

    -- Delay from phy_data_o to memory
    constant TX_OUTPUT_DELAY : natural :=
        -- Write data: _ctrl_data.phy_data_o
        --  (=> output mux)
        --  => _phy_dbi.data_out_o
        --  => _phy_bitslip.data_o
        --  => TX_BITSLICE => DQ
        MUX_OUTPUT_DELAY + 2 + TX_BITSLICE_DELAY;

    -- Delay from phy_data_o to edc_write_i
    constant TX_EDC_DELAY : natural :=
        -- EDC for write data: _ctrl_data.phy_data_o
        --  (=> output mux)
        --  => _phy_dbi.data_out_o
        --  => _phy_crc.edc_o
        --  (=> input_mux)
        MUX_OUTPUT_DELAY + 2 + MUX_INPUT_DELAY;

    -- Delay from memory to phy_data_i
    constant RX_INPUT_DELAY : natural :=
        -- Read data: DQ => RX_BITSLICE
        --  => _phy_bitslip.data_i
        --  => _phy_dbi.data_in_o
        --  (=> input_mux)
        RX_BITSLICE_DELAY + 2 + MUX_INPUT_DELAY;

    -- Delay from memory to edc_read_i
    constant RX_EDC_DELAY : natural :=
        -- EDC for read data: DQ => RX_BITSLICE
        --  => _phy_bitslip.data_i
        --  => _phy_crc.edc_o
        --  (=> input_mux)
        RX_BITSLICE_DELAY + 2 + MUX_INPUT_DELAY;

    -- Delay from memory to edc_in_i
    constant EDC_INPUT_DELAY : natural :=
        -- EDC from SG: EDC => RX_BITSLICE
        --  => _phy_bitslip.data_i
        --  (=> input_mux)
        RX_BITSLICE_DELAY + 1 + MUX_INPUT_DELAY;
end;
