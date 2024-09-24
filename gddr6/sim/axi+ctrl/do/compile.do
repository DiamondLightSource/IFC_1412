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
    $common_vhd/util/flow_control.vhd \
    $common_vhd/util/sync_bit.vhd \
    $common_vhd/util/fifo.vhd \
    $common_vhd/util/short_delay.vhd \
    $common_vhd/util/memory_array.vhd \
    $common_vhd/util/long_delay.vhd \
    $common_vhd/util/fixed_delay_dram.vhd \
    $common_vhd/util/fixed_delay.vhd \
    $common_vhd/async_fifo/async_fifo_address.vhd \
    $common_vhd/async_fifo/async_fifo_reset.vhd \
    $common_vhd/async_fifo/async_fifo.vhd \
    $vhd_dir/gddr6_defs.vhd \
    $vhd_dir/phy/gddr6_phy_crc.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_command_defs.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_defs.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_timing_defs.vhd \
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
    $vhd_dir/axi/gddr6_axi.vhd

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/../../common/decode_commands.vhd \
    $bench_dir/sim_phy_defs.vhd \
    $bench_dir/sim_phy_memory.vhd \
    $bench_dir/sim_phy.vhd \
    $bench_dir/sim_axi_master.vhd \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "AXI" axi/*
add wave -group "CTRL" ctrl/*
add wave -group "CTRL.DATA" ctrl/data/*
add wave -group "PHY Memory" phy/memory/*
add wave -group "PHY" phy/* phy/vars/*
add wave -group "AXI master" master/*
add wave -group "Bench" sim:*

quietly set NumericStdNoWarnings 1

run 1 us

# vim: set filetype=tcl:
