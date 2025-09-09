-- Delay definitions for aligning streams

-- These definitions capture the key delays between CTRL and the SG and are
-- dependent on the precise implementation of the PHY layer and the behaviour of
-- the BITSLICE components.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gddr6_ctrl_timing_defs.all;

package gddr6_ctrl_delay_defs is
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- Delays determined by hardware

    -- The following delays are measured from input to the appropriate BITSLICE
    -- input in _phy_nibble to the corresponding output.
    constant TX_BITSLICE_DELAY : natural := 2;
    constant RX_BITSLICE_DELAY : natural := 5;
    constant TRI_BITSLICE_DELAY : natural := TX_BITSLICE_DELAY + 1;

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- Delays determined by implementation

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


    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- Delays for data alignment

    -- Delay for Output Enable
    constant OUTPUT_ENABLE_DELAY : natural :=
        CA_OUTPUT_DELAY + WLmrs - OE_OUTPUT_DELAY;
    -- Output enable needs to be active one tick early, one tick late, and for
    -- two ticks during the write, so we stretch the enable to 4 ticks total.
    constant OUTPUT_ENABLE_STRETCH : natural := 4;

    -- Delays for read
    --
    -- Time of arrival of read data after command completion
    constant READ_START_DELAY : natural :=
        CA_OUTPUT_DELAY + RLmrs + RX_INPUT_DELAY;
    -- Time of arrival of read EDC response from SG after completion
    constant READ_CHECK_DELAY : natural :=
        CA_OUTPUT_DELAY + RLmrs + CRCRL + EDC_INPUT_DELAY;
    -- Delay to align PHY and SG EDC signals
    constant READ_EDC_DELAY : natural :=
        READ_CHECK_DELAY - READ_START_DELAY;

    -- Delays for write
    --
    -- Time to send write data after command completion
    constant WRITE_START_DELAY : natural :=
        CA_OUTPUT_DELAY + WLmrs - TX_OUTPUT_DELAY;
    -- Time of arrival of write EDC response from SG after completion
    constant WRITE_CHECK_DELAY : natural :=
        CA_OUTPUT_DELAY + WLmrs + CRCWL + EDC_INPUT_DELAY;
    -- Delay to align PHY and SG EDC signals
    constant WRITE_EDC_DELAY : natural :=
        WRITE_CHECK_DELAY - WRITE_START_DELAY - TX_EDC_DELAY;
end;
