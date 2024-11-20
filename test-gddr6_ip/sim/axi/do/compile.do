# Paths from environment
set vhd_dir $env(VHD_DIR)
set common_vhd $env(COMMON_VHD)
set bench_dir $env(BENCH_DIR)
set common_sim $env(COMMON_SIM)
set gddr6_dir $env(GDDR6_DIR)

vlib work
vlib msim
vlib msim/xil_defaultlib

vcom -64 -2008 -work xil_defaultlib \
    $common_vhd/support.vhd \
    $common_vhd/util/memory_array.vhd \
    $common_vhd/util/stretch_pulse.vhd \
    $common_vhd/register/register_defs.vhd \
    $common_vhd/register/register_command.vhd \
    $common_vhd/register/register_file.vhd \
    $common_vhd/register/register_file_rw.vhd \
    built_dir/register_defines.vhd \
    $gddr6_dir/gddr6_defs.vhd \
    $vhd_dir/axi_data.vhd \
    $vhd_dir/axi_address.vhd \
    $vhd_dir/axi_stats.vhd \
    $vhd_dir/axi.vhd

vcom -64 -2008 -work xil_defaultlib \
    $common_sim/sim_support.vhd \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "AXI Data" axi/data/*
add wave -group "AXI Address" axi/address/*
add wave -group "AXI" axi/*
add wave -group "Bench" sim:*

quietly set NumericStdNoWarnings 1

run 1.2 us

# vim: set filetype=tcl:
