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
    $vhd_dir/ctrl/gddr6_ctrl_command_defs.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_defs.vhd \
    $vhd_dir/ctrl/gddr6_ctrl_write.vhd

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/../../common/decode_commands.vhd \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "Write" write_inst/* write_inst/proc/*
add wave -group "Bench" sim:*

quietly set NumericStdNoWarnings 1

# run 110 ns
run 1 us

# vim: set filetype=tcl:
