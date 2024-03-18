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
    $vhd_dir/ctrl/gddr6_ctrl_timing_defs.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_command_defs.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_core_defs.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_bank.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_banks.vhd

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "Bank(0)" banks/gen_banks(0)/bank_inst/*
add wave -group "Bank(1)" banks/gen_banks(1)/bank_inst/*
add wave -group "Banks" banks/*
add wave -group "Bench" sim:*

quietly set NumericStdNoWarnings 1

run 1 us

# vim: set filetype=tcl:
