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
    $common_vhd/util/memory_array.vhd \
    $common_vhd/util/sync_bit.vhd \
    $common_vhd/register/register_defs.vhd \
    built_dir/mailbox_register_defines.vhd \
    $vhd_dir/mailbox_io.vhd \
    $vhd_dir/debounce.vhd \
    $vhd_dir/i2c_signals.vhd \
    $vhd_dir/i2c_core.vhd \
    $vhd_dir/mailbox_slave.vhd \
    $vhd_dir/mailbox.vhd

vcom -64 -2008 -work xil_defaultlib \
    $common_sim/sim_support.vhd \
    $bench_dir/i2c_master.vhd \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "IO" mailbox/io/*
add wave -group "Signals" mailbox/core/signals/*
add wave -group "Core" mailbox/core/*
add wave -group "Slave RX" mailbox/slave/rx_messages/*
add wave -group "Slave TX" mailbox/slave/tx_messages/*
add wave -group "Slave" mailbox/slave/*
add wave -group "Mailbox" mailbox/*
add wave -group "Bench" sim:*


set NumericStdNoWarnings 1

run 2.5 ms

# vim: set filetype=tcl:
