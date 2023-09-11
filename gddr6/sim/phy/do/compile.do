# Paths from environment
set vhd_dir $env(VHD_DIR)
set common_vhd $env(COMMON_VHD)
set bench_dir $env(BENCH_DIR)

vlib work
vlib msim
vlib msim/xil_defaultlib

vcom -64 -2008 -work xil_defaultlib \
    $common_vhd/support.vhd \
    $common_vhd/iodefs/ibufds_array.vhd \
    $common_vhd/iodefs/ibuf_array.vhd \
    $common_vhd/iodefs/obuf_array.vhd \
    $common_vhd/iodefs/iobuf_array.vhd \
    $common_vhd/util/sync_bit.vhd \
    $vhd_dir/gddr6_config_defs.vhd \
    $vhd_dir/phy/gddr6_phy_defs.vhd \
    $vhd_dir/phy/gddr6_phy_io.vhd \
    $vhd_dir/phy/gddr6_phy_clocking.vhd \
    $vhd_dir/phy/gddr6_phy_ca.vhd \
    $vhd_dir/phy/gddr6_phy_nibble.vhd \
    $vhd_dir/phy/gddr6_phy_byte.vhd \
    $vhd_dir/phy/gddr6_phy_dq_remap.vhd \
    $vhd_dir/phy/gddr6_phy_bitslip.vhd \
    $vhd_dir/phy/gddr6_phy_map_data.vhd \
    $vhd_dir/phy/gddr6_phy_crc.vhd \
    $vhd_dir/phy/gddr6_phy_dq.vhd \
    $vhd_dir/phy/gddr6_phy_riu_control.vhd \
    $vhd_dir/phy/gddr6_phy.vhd

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "IO" /phy/io/*
add wave -group "Clocking" /phy/clocking/*
add wave -group "CA" /phy/ca/*
add wave -group "Map Data" /phy/dq/map_data/*
add wave -group "CRC" /phy/dq/crc/*
add wave -group "DQ" /phy/dq/*
add wave -group "RIU" /phy/riu_control/*
add wave -group "Phy" /phy/*
add wave -group "Bench" sim:*


run 2.5 us

# vim: set filetype=tcl: