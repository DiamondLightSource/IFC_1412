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
    $vhd_dir/axi/gddr6_axi_defs.vhd \
    $vhd_dir/axi/gddr6_axi_address.vhd \
    $vhd_dir/axi/gddr6_axi_address_fifo.vhd \
    $vhd_dir/axi/gddr6_axi_command_fifo.vhd \
    $vhd_dir/axi/gddr6_axi_ctrl.vhd \
    $vhd_dir/axi/gddr6_axi_write_response_fifo.vhd \
    $vhd_dir/axi/gddr6_axi_write_response.vhd \
    $vhd_dir/axi/gddr6_axi_write_data_fifo.vhd \
    $vhd_dir/axi/gddr6_axi_write_status_fifo.vhd \
    $vhd_dir/axi/gddr6_axi_write_data.vhd \
    $vhd_dir/axi/gddr6_axi_write.vhd


vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "CTRL" axi_write/ctrl/*
# add wave -group "Data FIFO Address" axi_write/data_fifo/async_address/*
add wave -group "Data FIFO" axi_write/data_fifo/*
add wave -group "WA" axi_write/address/*
add wave -group "W" axi_write/data/* axi_write/data/vars/*
add wave -group "B" axi_write/response/*
add wave -group "Write" axi_write/*
add wave -group "Bench" sim:*

quietly set NumericStdNoWarnings 1

run 1 us

# vim: set filetype=tcl:
