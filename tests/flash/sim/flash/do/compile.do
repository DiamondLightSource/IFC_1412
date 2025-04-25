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
    $common_vhd/register/register_defs.vhd \
    built_dir/register_defines.vhd \
    $vhd_dir/flash.vhd

vcom -64 -2008 -work xil_defaultlib \
    $common_sim/sim_support.vhd \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "FLASH" sim:/testbench/flash/*
add wave -group "Bench" sim:*


run 500 ns

# vim: set filetype=tcl:
