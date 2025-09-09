# Paths from environment
set vhd_dir $env(VHD_DIR)
set common_vhd $env(COMMON_VHD)
set bench_dir $env(BENCH_DIR)
set gddr6_dir $env(GDDR6_DIR)

vlib work
vlib msim
vlib msim/xil_defaultlib

vcom -64 -2008 -work xil_defaultlib \
    $common_vhd/support.vhd \
    $common_vhd/register/register_defs.vhd \
    $vhd_dir/system_clocking.vhd \
    $bench_dir/interconnect_wrapper.vhd \
    $common_vhd/axi/axi_lite_slave.vhd \
    built_dir/register_defines.vhd \
    built_dir/gddr6_register_defines.vhd \
    built_dir/version.vhd \
    $gddr6_dir/gddr6_defs.vhd \
    $gddr6_dir/gddr6_ip_defs.vhd \
    built_dir/test_gddr6_phy.vhd.dummy \
    built_dir/top_entity.vhd \
    $vhd_dir/top.vhd

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "Top" sim:/testbench/top/*
add wave -group "Bench" sim:*


run 50 ns

# vim: set filetype=tcl:
