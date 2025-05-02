# Paths from environment
set vhd_dir $env(VHD_DIR)
set common_vhd $env(COMMON_VHD)
set common_sim $env(COMMON_SIM)
set bench_dir $env(BENCH_DIR)

vlib work
vlib msim
vlib msim/xil_defaultlib

vcom -64 -2008 -work xil_defaultlib \
    $common_vhd/support.vhd \
    $common_vhd/util/memory_array.vhd \
    $common_vhd/util/long_delay.vhd \
    $common_vhd/util/fixed_delay_dram.vhd \
    $common_vhd/util/fixed_delay.vhd \
    $common_vhd/util/fifo.vhd \
    $common_vhd/register/register_defs.vhd \
    built_dir/register_defines.vhd \
    $vhd_dir/flash_control.vhd \
    $vhd_dir/flash_mo_fifo.vhd \
    $vhd_dir/flash_mi_fifo.vhd \
    $vhd_dir/flash_spi_core.vhd \
    $vhd_dir/flash_io.vhd \
    $vhd_dir/flash.vhd

vcom -64 -2008 -work xil_defaultlib \
    $common_sim/sim_support.vhd \
    $bench_dir/sim_spi.vhd \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "Control" sim:/testbench/flash/control/*
add wave -group "MO FIFO" sim:/testbench/flash/mo_fifo/*
add wave -group "MI FIFO" sim:/testbench/flash/mi_fifo/*
add wave -group "Core" sim:/testbench/flash/core/*
add wave -group "IO" sim:/testbench/flash/io/*
add wave -group "FLASH" sim:/testbench/flash/*
add wave -group "Bench" sim:*


run 1 us

# vim: set filetype=tcl:
