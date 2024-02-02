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
    $common_vhd/util/memory_array.vhd \
    $common_vhd/util/long_delay.vhd \
    $common_vhd/util/fixed_delay_dram.vhd \
    $common_vhd/util/fixed_delay.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_timing_defs.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_commands.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_core_defs.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_timing_defs.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_read.vhd

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "Read" read/*
add wave -group "Bench" sim:*

quietly set NumericStdNoWarnings 1

run 250 ns

# vim: set filetype=tcl:
