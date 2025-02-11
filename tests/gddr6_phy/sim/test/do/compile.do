# Paths from environment
set vhd_dir $env(VHD_DIR)
set common_vhd $env(COMMON_VHD)
set bench_dir $env(BENCH_DIR)
set common_sim $env(COMMON_SIM)
set gddr6_dir $env(GDDR6_DIR)

set gddr6_common_sim $bench_dir/../../../../gddr6/sim/common

vlib work
vlib msim
vlib msim/xil_defaultlib

vcom -64 -2008 -work xil_defaultlib \
    $common_vhd/support.vhd \
    built_dir/register_defines.vhd \
    built_dir/gddr6_register_defines.vhd \
    built_dir/version.vhd \
    $common_vhd/util/sync_reset.vhd \
    $common_vhd/util/sync_bit.vhd \
    $common_vhd/util/sync_pulse.vhd \
    $common_vhd/util/memory_array.vhd \
    $common_vhd/util/flow_control.vhd \
    $common_vhd/util/fifo.vhd \
    $common_vhd/util/memory_array_dual.vhd \
    $common_vhd/util/long_delay.vhd \
    $common_vhd/util/fixed_delay_dram.vhd \
    $common_vhd/util/fixed_delay.vhd \
    $common_vhd/util/dlyreg.vhd \
    $common_vhd/util/short_delay.vhd \
    $common_vhd/util/stretch_pulse.vhd \
    $common_vhd/util/cross_clocks.vhd \
    $common_vhd/util/cross_clocks_write.vhd \
    $common_vhd/util/cross_clocks_read.vhd \
    $common_vhd/util/cross_clocks_write_read.vhd \
    $common_vhd/util/strobe_ack.vhd \
    $common_vhd/async_fifo/async_fifo_address.vhd \
    $common_vhd/async_fifo/async_fifo_reset.vhd \
    $common_vhd/async_fifo/async_fifo.vhd \
    $common_vhd/register/register_defs.vhd \
    $common_vhd/register/register_buffer.vhd \
    $common_vhd/register/register_mux_strobe.vhd \
    $common_vhd/register/register_mux.vhd \
    $common_vhd/register/register_file.vhd \
    $common_vhd/register/register_file_cc.vhd \
    $common_vhd/register/register_file_rw.vhd \
    $common_vhd/register/register_events.vhd \
    $common_vhd/register/register_status.vhd \
    $common_vhd/register/register_command.vhd \
    $common_vhd/register/register_bank_cc.vhd \
    $common_vhd/register/register_cc.vhd \
    $common_vhd/register/register_read_block.vhd \
    $common_vhd/misc/spi_master.vhd \
    $common_vhd/iodefs/ibufds_array.vhd \
    $common_vhd/iodefs/ibuf_array.vhd \
    $common_vhd/iodefs/obuf_array.vhd \
    $common_vhd/iodefs/iobuf_array.vhd \
    $gddr6_dir/gddr6_defs.vhd \
    $gddr6_dir/gddr6_config_defs.vhd \
    $gddr6_dir/phy/gddr6_phy_defs.vhd \
    $gddr6_dir/phy/gddr6_phy_io.vhd \
    $gddr6_dir/phy/gddr6_phy_clocking.vhd \
    $gddr6_dir/phy/gddr6_phy_reset.vhd \
    $gddr6_dir/phy/gddr6_phy_ca.vhd \
    $gddr6_dir/phy/gddr6_phy_nibble.vhd \
    $gddr6_dir/phy/gddr6_phy_byte.vhd \
    $gddr6_dir/phy/gddr6_phy_remap.vhd \
    $gddr6_dir/phy/gddr6_phy_bitslices.vhd \
    $gddr6_dir/phy/gddr6_phy_dbi.vhd \
    $gddr6_dir/phy/gddr6_phy_bitslip.vhd \
    $gddr6_dir/phy/gddr6_phy_crc.vhd \
    $gddr6_dir/phy/gddr6_phy_dq.vhd \
    $gddr6_dir/phy/gddr6_phy_delay_control.vhd \
    $gddr6_dir/phy/gddr6_phy.vhd \
    $gddr6_dir/setup/gddr6_setup_control.vhd \
    $gddr6_dir/setup/gddr6_setup_buffers.vhd \
    $gddr6_dir/setup/gddr6_setup_exchange.vhd \
    $gddr6_dir/setup/gddr6_setup_delay.vhd \
    $gddr6_dir/setup/gddr6_setup.vhd \
    $gddr6_dir/gddr6_setup_phy.vhd \
    $gddr6_dir/ctrl/gddr6_ctrl_command_defs.vhd \
    $gddr6_dir/ctrl/gddr6_ctrl_defs.vhd \
    $gddr6_dir/ctrl/gddr6_ctrl_timing_defs.vhd \
    $gddr6_dir/ctrl/gddr6_ctrl_delay_defs.vhd \
    $gddr6_dir/ctrl/gddr6_ctrl_tuning_defs.vhd \
    $gddr6_dir/ctrl/gddr6_ctrl_read.vhd \
    $gddr6_dir/ctrl/gddr6_ctrl_write.vhd \
    $gddr6_dir/ctrl/gddr6_ctrl_lookahead.vhd \
    $gddr6_dir/ctrl/gddr6_ctrl_admin.vhd \
    $gddr6_dir/ctrl/gddr6_ctrl_refresh.vhd \
    $gddr6_dir/ctrl/gddr6_ctrl_bank.vhd \
    $gddr6_dir/ctrl/gddr6_ctrl_banks.vhd \
    $gddr6_dir/ctrl/gddr6_ctrl_mux.vhd \
    $gddr6_dir/ctrl/gddr6_ctrl_request.vhd \
    $gddr6_dir/ctrl/gddr6_ctrl_command.vhd \
    $gddr6_dir/ctrl/gddr6_ctrl_data.vhd \
    $gddr6_dir/ctrl/gddr6_ctrl.vhd \
    $gddr6_dir/axi/gddr6_axi_defs.vhd \
    $gddr6_dir/axi/gddr6_axi_address.vhd \
    $gddr6_dir/axi/gddr6_axi_address_fifo.vhd \
    $gddr6_dir/axi/gddr6_axi_command_fifo.vhd \
    $gddr6_dir/axi/gddr6_axi_ctrl.vhd \
    $gddr6_dir/axi/gddr6_axi_read_data.vhd \
    $gddr6_dir/axi/gddr6_axi_read_data_fifo.vhd \
    $gddr6_dir/axi/gddr6_axi_read.vhd \
    $gddr6_dir/axi/gddr6_axi_write_response_fifo.vhd \
    $gddr6_dir/axi/gddr6_axi_write_response.vhd \
    $gddr6_dir/axi/gddr6_axi_write_data_fifo.vhd \
    $gddr6_dir/axi/gddr6_axi_write_status_fifo.vhd \
    $gddr6_dir/axi/gddr6_axi_write_data.vhd \
    $gddr6_dir/axi/gddr6_axi_write.vhd \
    $gddr6_dir/axi/gddr6_axi_stats.vhd \
    $gddr6_dir/axi/gddr6_axi.vhd \
    $gddr6_dir/gddr6.vhd \
    $vhd_dir/lmk04616/lmk04616_io.vhd \
    $vhd_dir/lmk04616/lmk04616_control.vhd \
    $vhd_dir/lmk04616/lmk04616.vhd \
    $vhd_dir/axi_data.vhd \
    $vhd_dir/axi_address.vhd \
    $vhd_dir/axi_stats.vhd \
    $vhd_dir/axi.vhd \
    $vhd_dir/test_gddr6_phy.vhd

vcom -64 -2008 -work xil_defaultlib \
    $gddr6_common_sim/decode_command_defs.vhd \
    $gddr6_common_sim/decode_commands.vhd \
    $common_sim/sim_support.vhd \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

source groups.tcl

view wave

with_group GDDR6 test/gddr6 {
    with_group PHY setup_phy/phy {
        add_wave IO io
        add_wave signals
    }
    with_group SETUP setup_phy/setup {
        add_wave Control control
        add_wave Exchange exchange
        add_wave Exchange.Buffers exchange/buffers
        add_wave Delay delay
        add_wave signals
    }
    with_group CTRL ctrl {
        add_wave signals
    }
    with_group AXI axi {
        add_wave signals
    }
    add_wave signals
}

with_group TEST test {
    add_wave AXI.DATA axi/data
    add_wave AXI axi
    add_wave signals
}

add wave -group "Bench" sim:*

quietly set NumericStdNoWarnings 1

run 3 us

# vim: set filetype=tcl:
