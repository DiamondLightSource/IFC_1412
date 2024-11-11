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
    $common_vhd/util/short_delay.vhd \
    $common_vhd/util/memory_array.vhd \
    $common_vhd/util/long_delay.vhd \
    $common_vhd/util/fixed_delay_dram.vhd \
    $common_vhd/util/fixed_delay.vhd \
    $common_vhd/util/stretch_pulse.vhd \
    $common_vhd/util/strobe_ack.vhd \
    $common_vhd/util/cross_clocks.vhd \
    $common_vhd/util/cross_clocks_write.vhd \
    $vhd_dir/gddr6_config_defs.vhd \
    $vhd_dir/gddr6_defs.vhd \
    $vhd_dir/phy/gddr6_phy_defs.vhd \
    $vhd_dir/phy/gddr6_phy_io.vhd \
    $vhd_dir/phy/gddr6_phy_clocking.vhd \
    $vhd_dir/phy/gddr6_phy_reset.vhd \
    $vhd_dir/phy/gddr6_phy_ca.vhd \
    $vhd_dir/phy/gddr6_phy_nibble.vhd \
    $vhd_dir/phy/gddr6_phy_byte.vhd \
    $vhd_dir/phy/gddr6_phy_remap.vhd \
    $vhd_dir/phy/gddr6_phy_bitslices.vhd \
    $vhd_dir/phy/gddr6_phy_bitslip.vhd \
    $vhd_dir/phy/gddr6_phy_dbi.vhd \
    $vhd_dir/phy/gddr6_phy_crc.vhd \
    $vhd_dir/phy/gddr6_phy_dq.vhd \
    $vhd_dir/phy/gddr6_phy_delay_control.vhd \
    $vhd_dir/phy/gddr6_phy.vhd

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "IO" /phy/io/*
add wave -group "Clocking" /phy/clocking/*
add wave -group "Reset" /phy/reset/*
add wave -group "CA" /phy/ca/*
add wave -group "DQ Nibble(0)" \
    /phy/bitslices/gen_bytes(0)/byte/gen_nibble(0)/nibble/*
add wave -group "Map Slices" /phy/bitslices/map_slices/*
add wave -group "Bitslip" /phy/dq/bitslip_out/*
add wave -group "Write CRC" /phy/dq/write_crc/*
add wave -group "Read CRC" /phy/dq/read_crc/*
add wave -group "DQ" /phy/dq/*
add wave -group "Delay" /phy/delay/*
add wave -group "Phy" /phy/*
add wave -group "Bench" sim:*


run 4.5 us

# vim: set filetype=tcl:
