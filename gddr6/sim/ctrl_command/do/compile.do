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
    $vhd_dir/ctrl/gddr6_ctrl_banks.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_request_mux.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_request.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_command.vhd

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/../../common/decode_commands.vhd \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "Banks" command/banks/*
add wave -group "Mux" command/request_mux/*
add wave -group "Request" command/request/*
add wave -group "Command" command/*
add wave -group "Decode" decode/*
add wave -group "Bench" sim:*

quietly set NumericStdNoWarnings 1

run 500 ns

# vim: set filetype=tcl:
