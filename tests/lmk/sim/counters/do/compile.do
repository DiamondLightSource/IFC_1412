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
    $common_vhd/util/sync_bit.vhd \
    $common_vhd/util/cross_clocks.vhd \
    $common_vhd/util/cross_clocks_read.vhd \
    $vhd_dir/frequency_counters.vhd

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "Handshake(0)" counters/gen_counters(0)/sync_read/*
add wave -group "Count(0)" counters/gen_counters(0)/*
add wave -group "Counters" counters/*
add wave -group "Bench" sim:*


run 8 us

# vim: set filetype=tcl:
