# Paths from environment
set bench_dir $env(BENCH_DIR)

vlib work
vlib msim
vlib msim/xil_defaultlib

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/simple_fifo.vhd \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "FIFO" /fifo/*
add wave -group "Bench" sim:*

run 100 ns

# vim: set filetype=tcl:
