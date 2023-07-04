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
    built_dir/register_defines.vhd \
    built_dir/version.vhd \
    $common_vhd/misc/spi_master.vhd \
    $common_vhd/register/register_defs.vhd \
    $common_vhd/register/register_events.vhd \
    $common_vhd/register/register_file_rw.vhd \
    $vhd_dir/lmk04616_io.vhd \
    $vhd_dir/lmk04616_control.vhd \
    $vhd_dir/lmk04616.vhd \
    $vhd_dir/top_registers.vhd

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/sim_lmk04616.vhd \
    $common_sim/sim_support.vhd \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "Sim" sim/*
add wave -group "LMK IO" lmk/io/*
add wave -group "LMK SPI" lmk/spi/*
add wave -group "LMK Control" lmk/control/*
add wave -group "LMK" lmk/*
add wave -group "Regs" registers/*
add wave -group "Bench" sim:*


run 8 us

# vim: set filetype=tcl:
