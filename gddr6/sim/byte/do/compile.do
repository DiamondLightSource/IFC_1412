# Paths from environment
set vhd_dir $env(VHD_DIR)
set common_vhd $env(COMMON_VHD)
set bench_dir $env(BENCH_DIR)

vlib work
vlib msim
vlib msim/xil_defaultlib

vcom -64 -2008 -work xil_defaultlib \
    $common_vhd/support.vhd \
    $vhd_dir/phy/gddr6_phy_nibble.vhd \
    $vhd_dir/phy/gddr6_phy_byte.vhd

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

# add wave -group "Control" /nibble/control/*
# add wave -group "Bitslice 1" /nibble/gen_bits(1)/gen_bitslice/bitslice/*
add wave -group "Byte" /byte/*
add wave -group "Bench" sim:*


run 5 us

# vim: set filetype=tcl:
