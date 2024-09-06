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
    $vhd_dir/axi/gddr6_axi_read_data.vhd \
    $vhd_dir/axi/gddr6_axi_read_data_fifo.vhd \
    $vhd_dir/axi/gddr6_axi_read.vhd

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "CTRL" axi_read/ctrl/*
add wave -group "Address FIFO core" axi_read/address_fifo/fifo/*
add wave -group "Address FIFO" axi_read/address_fifo/*
add wave -group "R" axi_read/data/* axi_read/data/vars/*
add wave -group "Data FIFO Address" axi_read/data_fifo/async_address/*
add wave -group "Data FIFO" axi_read/data_fifo/*
add wave -group "RA" axi_read/address/*
add wave -group "Read" axi_read/*
add wave -group "Bench" sim:*

quietly set NumericStdNoWarnings 1

run 8 us

# vim: set filetype=tcl:
