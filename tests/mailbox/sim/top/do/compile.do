# Paths from environment
set vhd_dir $env(VHD_DIR)
set common_vhd $env(COMMON_VHD)
set bench_dir $env(BENCH_DIR)
set file_list $env(FILE_LIST)
set mailbox_dir $env(MAILBOX_DIR)

vlib work
vlib msim
vlib msim/xil_defaultlib

# Load files from file-list
set infile [open $file_list]
set lines [split [read $infile] \n]
close $infile
set files [lsearch -regexp -inline -all $lines {^[^#]}]

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/interconnect_wrapper.vhd \
    {*}[subst -nocommands $files]

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "Top" sim:/testbench/top/*
add wave -group "Bench" sim:*


run 500 ns

# vim: set filetype=tcl:
