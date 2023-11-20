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
    $common_vhd/util/memory_array_dual.vhd \
    $common_vhd/util/sync_bit.vhd \
    $common_vhd/util/cross_clocks.vhd \
    $common_vhd/util/cross_clocks_write.vhd \
    $common_vhd/util/cross_clocks_write_read.vhd \
    $common_vhd/util/memory_array.vhd \
    $common_vhd/util/long_delay.vhd \
    $common_vhd/util/fixed_delay_dram.vhd \
    $common_vhd/util/fixed_delay.vhd \
    $common_vhd/util/dlyreg.vhd \
    $common_vhd/util/sync_pulse.vhd \
    $common_vhd/util/cross_clocks_read.vhd \
    $common_vhd/register/register_defs.vhd \
    $common_vhd/register/register_command.vhd \
    $common_vhd/register/register_bank_cc.vhd \
    $common_vhd/register/register_cc.vhd \
    $common_vhd/register/register_file_cc.vhd \
    $common_vhd/register/register_file.vhd \
    $common_vhd/register/register_file_rw.vhd \
    $common_vhd/register/register_read_block.vhd \
    $common_vhd/register/register_status.vhd \
    built_dir/gddr6_register_defines.vhd \
    $vhd_dir/setup/gddr6_setup_control.vhd \
    $vhd_dir/setup/gddr6_setup_buffers.vhd \
    $vhd_dir/setup/gddr6_setup_exchange.vhd \
    $vhd_dir/setup/gddr6_setup_delay.vhd \
    $vhd_dir/setup/gddr6_setup.vhd

vcom -64 -2008 -work xil_defaultlib \
    $common_sim/sim_support.vhd \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "Control" setup/control/*
add wave -group "DQ_in(0)" setup/exchange/buffers/gen_dq(0)/data_in/*
add wave -group "Buffers" setup/exchange/buffers/*
add wave -group "Exchange" setup/exchange/*
add wave -group "Delay" setup/delay/*
add wave -group "Setup" setup/*
add wave -group "Bench" sim:*


run 500 ns

# vim: set filetype=tcl:
