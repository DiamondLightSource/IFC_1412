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
    $common_vhd/util/short_delay.vhd \
    $common_vhd/util/memory_array.vhd \
    $common_vhd/util/long_delay.vhd \
    $common_vhd/util/fixed_delay_dram.vhd \
    $common_vhd/util/fixed_delay.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_command_defs.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_core_defs.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_timing_defs.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_read.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_write.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_lookahead.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_admin.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_refresh.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_bank.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_banks.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_mux.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_request.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_command.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_data.vhd \
    $vhd_dir/gddr6_defs.vhd \
    $vhd_dir/ctrl/gddr6_ctrl.vhd

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/../../common/decode_commands.vhd \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "Read" ctrl/read/*
add wave -group "Write" ctrl/write/*
add wave -group "Lookahead" ctrl/lookahead/*
add wave -group "Refresh" ctrl/refresh/*
add wave -group "Bank(1)" ctrl/command/banks/gen_banks(1)/bank_inst/*
add wave -group "Banks" ctrl/command/banks/*
add wave -group "Mux" ctrl/command/request_mux/*
add wave -group "Request" ctrl/command/request/*
add wave -group "Admin" ctrl/command/admin/*
add wave -group "Command" ctrl/command/*
add wave -group "Data" ctrl/data/*
add wave -group "Ctrl" ctrl/*
add wave -group "Bench" sim:*

quietly set NumericStdNoWarnings 1

run 300 ns
# run 5 us
# run 21 us

# vim: set filetype=tcl:
