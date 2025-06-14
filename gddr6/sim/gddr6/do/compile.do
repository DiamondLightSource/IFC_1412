# Paths from environment
set vhd_dir $env(VHD_DIR)
set common_vhd $env(COMMON_VHD)
set bench_dir $env(BENCH_DIR)
set common_sim $env(COMMON_SIM)

vlib work
vlib msim
vlib msim/xil_defaultlib

vcom -64 -2008 -work xil_defaultlib \
    $common_vhd/support.vhd \
    $common_vhd/iodefs/ibufds_array.vhd \
    $common_vhd/iodefs/ibuf_array.vhd \
    $common_vhd/iodefs/obuf_array.vhd \
    $common_vhd/iodefs/iobuf_array.vhd \
    $common_vhd/axi/axi_lite_slave.vhd \
    $common_vhd/util/flow_control.vhd \
    $common_vhd/util/sync_bit.vhd \
    $common_vhd/util/fifo.vhd \
    $common_vhd/util/short_delay.vhd \
    $common_vhd/util/memory_array.vhd \
    $common_vhd/util/memory_array_dual.vhd \
    $common_vhd/util/memory_array_dual_bytes.vhd \
    $common_vhd/util/long_delay.vhd \
    $common_vhd/util/fixed_delay_dram.vhd \
    $common_vhd/util/fixed_delay.vhd \
    $common_vhd/util/dlyreg.vhd \
    $common_vhd/util/stretch_pulse.vhd \
    $common_vhd/util/edge_detect.vhd \
    $common_vhd/util/strobe_ack.vhd \
    $common_vhd/util/cross_clocks.vhd \
    $common_vhd/util/cross_clocks_write.vhd \
    $common_vhd/util/cross_clocks_read.vhd \
    $common_vhd/util/cross_clocks_write_read.vhd \
    $common_vhd/async_fifo/async_fifo_address.vhd \
    $common_vhd/async_fifo/async_fifo_reset.vhd \
    $common_vhd/async_fifo/async_fifo.vhd \
    $common_vhd/register/register_defs.vhd \
    $common_vhd/register/register_buffer.vhd \
    $common_vhd/register/register_mux_strobe.vhd \
    $common_vhd/register/register_mux.vhd \
    $common_vhd/register/register_file.vhd \
    $common_vhd/register/register_file_rw.vhd \
    $common_vhd/register/register_file_cc.vhd \
    $common_vhd/register/register_events.vhd \
    $common_vhd/register/register_status.vhd \
    $common_vhd/register/register_command.vhd \
    $common_vhd/register/register_bank_cc.vhd \
    $common_vhd/register/register_cc.vhd \
    $common_vhd/register/register_read_block.vhd \
    $vhd_dir/gddr6_config_defs.vhd \
    $vhd_dir/gddr6_defs.vhd \
    $vhd_dir/gddr6_ip_defs.vhd \
    $vhd_dir/phy/gddr6_phy_defs.vhd \
    $vhd_dir/phy/gddr6_phy_io.vhd \
    $vhd_dir/phy/gddr6_phy_clocking.vhd \
    $vhd_dir/phy/gddr6_phy_reset.vhd \
    $vhd_dir/phy/gddr6_phy_ca.vhd \
    $vhd_dir/phy/gddr6_phy_nibble.vhd \
    $vhd_dir/phy/gddr6_phy_byte.vhd \
    $vhd_dir/phy/gddr6_phy_remap.vhd \
    $vhd_dir/phy/gddr6_phy_bitslices.vhd \
    $vhd_dir/phy/gddr6_phy_bitslip.vhd \
    $vhd_dir/phy/gddr6_phy_dbi.vhd \
    $vhd_dir/phy/gddr6_phy_crc.vhd \
    $vhd_dir/phy/gddr6_phy_dq.vhd \
    $vhd_dir/phy/gddr6_phy_delay_control.vhd \
    $vhd_dir/phy/gddr6_phy.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_command_defs.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_defs.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_timing_defs.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_delay_defs.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_tuning_defs.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_read.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_write.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_lookahead.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_admin.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_refresh.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_bank.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_banks.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_mux.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_request.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_command.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_temps.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_data.vhd \
    $vhd_dir/ctrl/gddr6_ctrl.vhd \
    $vhd_dir/axi/gddr6_axi_defs.vhd \
    $vhd_dir/axi/gddr6_axi_address.vhd \
    $vhd_dir/axi/gddr6_axi_address_fifo.vhd \
    $vhd_dir/axi/gddr6_axi_command_fifo.vhd \
    $vhd_dir/axi/gddr6_axi_ctrl.vhd \
    $vhd_dir/axi/gddr6_axi_read_data.vhd \
    $vhd_dir/axi/gddr6_axi_read_data_fifo.vhd \
    $vhd_dir/axi/gddr6_axi_read.vhd \
    $vhd_dir/axi/gddr6_axi_write_response_fifo.vhd \
    $vhd_dir/axi/gddr6_axi_write_response.vhd \
    $vhd_dir/axi/gddr6_axi_write_data_fifo.vhd \
    $vhd_dir/axi/gddr6_axi_write_status_fifo.vhd \
    $vhd_dir/axi/gddr6_axi_write_data.vhd \
    $vhd_dir/axi/gddr6_axi_write.vhd \
    $vhd_dir/axi/gddr6_axi_stats.vhd \
    $vhd_dir/axi/gddr6_axi.vhd \
    built_dir/gddr6_register_defines.vhd \
    $vhd_dir/setup/gddr6_setup_control.vhd \
    $vhd_dir/setup/gddr6_setup_buffers.vhd \
    $vhd_dir/setup/gddr6_setup_exchange.vhd \
    $vhd_dir/setup/gddr6_setup_delay.vhd \
    $vhd_dir/setup/gddr6_setup.vhd \
    $vhd_dir/gddr6.vhd

vcom -64 -93 -work xil_defaultlib \
    $vhd_dir/gddr6_ip.vhd

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "GDDR6" gddr6/*
add wave -group "Bench" sim:*

quietly set NumericStdNoWarnings 1

run 100 ns

# vim: set filetype=tcl:
