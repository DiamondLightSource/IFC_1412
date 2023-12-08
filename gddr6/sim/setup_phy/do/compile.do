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
    $common_vhd/util/sync_reset.vhd \
    $common_vhd/util/sync_bit.vhd \
    $common_vhd/util/sync_pulse.vhd \
    $common_vhd/util/memory_array.vhd \
    $common_vhd/util/memory_array_dual.vhd \
    $common_vhd/util/long_delay.vhd \
    $common_vhd/util/fixed_delay_dram.vhd \
    $common_vhd/util/fixed_delay.vhd \
    $common_vhd/util/dlyreg.vhd \
    $common_vhd/util/stretch_pulse.vhd \
    $common_vhd/util/cross_clocks.vhd \
    $common_vhd/util/cross_clocks_write.vhd \
    $common_vhd/util/cross_clocks_read.vhd \
    $common_vhd/util/cross_clocks_write_read.vhd \
    $common_vhd/util/short_delay.vhd \
    $common_vhd/util/strobe_ack.vhd \
    $common_vhd/register/register_defs.vhd \
    $common_vhd/register/register_buffer.vhd \
    $common_vhd/register/register_mux_strobe.vhd \
    $common_vhd/register/register_mux.vhd \
    $common_vhd/register/register_file.vhd \
    $common_vhd/register/register_file_rw.vhd \
    $common_vhd/register/register_file_cc.vhd \
    $common_vhd/register/register_events.vhd \
    $common_vhd/register/register_status.vhd \
    $common_vhd/register/register_command.vhd \
    $common_vhd/register/register_bank_cc.vhd \
    $common_vhd/register/register_cc.vhd \
    $common_vhd/register/register_read_block.vhd \
    $common_vhd/misc/spi_master.vhd \
    $common_vhd/iodefs/ibufds_array.vhd \
    $common_vhd/iodefs/ibuf_array.vhd \
    $common_vhd/iodefs/obuf_array.vhd \
    $common_vhd/iodefs/iobuf_array.vhd \
    $vhd_dir/gddr6_config_defs.vhd \
    $vhd_dir/gddr6_defs.vhd \
    $vhd_dir/phy/gddr6_phy_defs.vhd \
    $vhd_dir/phy/gddr6_phy_io.vhd \
    $vhd_dir/phy/gddr6_phy_clocking.vhd \
    $vhd_dir/phy/gddr6_phy_ca.vhd \
    $vhd_dir/phy/gddr6_phy_nibble.vhd \
    $vhd_dir/phy/gddr6_phy_byte.vhd \
    $vhd_dir/phy/gddr6_phy_map_dbi.vhd \
    $vhd_dir/phy/gddr6_phy_bitslip.vhd \
    $vhd_dir/phy/gddr6_phy_dq_remap.vhd \
    $vhd_dir/phy/gddr6_phy_crc_core.vhd \
    $vhd_dir/phy/gddr6_phy_crc.vhd \
    $vhd_dir/phy/gddr6_phy_dq.vhd \
    $vhd_dir/phy/gddr6_phy_delay_control.vhd \
    $vhd_dir/phy/gddr6_phy.vhd \
    built_dir/gddr6_register_defines.vhd \
    $vhd_dir/setup/gddr6_setup_control.vhd \
    $vhd_dir/setup/gddr6_setup_buffers.vhd \
    $vhd_dir/setup/gddr6_setup_exchange.vhd \
    $vhd_dir/setup/gddr6_setup_delay.vhd \
    $vhd_dir/setup/gddr6_setup.vhd \
    $vhd_dir/gddr6_setup_phy.vhd

vcom -64 -2008 -work xil_defaultlib \
    $common_sim/sim_support.vhd \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "PHY IO" test/phy/io/*
add wave -group "PHY Clocking" test/phy/clocking/*
add wave -group "PHY CA" test/phy/ca/*
add wave -group "PHY Nibble(0)(0)" \
    test/phy/dq/gen_bytes(0)/byte/gen_nibble(0)/nibble/*
add wave -group "PHY Byte(0)" test/phy/dq/gen_bytes(0)/byte/*
add wave -group "PHY DBI" test/phy/dq/dbi/*
add wave -group "PHY Bitslip" test/phy/dq/bitslip/*
add wave -group "PHY CRC" test/phy/dq/crc/*
add wave -group "PHY DQ" test/phy/dq/*
add wave -group "PHY Delay" test/phy/delay/*
add wave -group "PHY" test/phy/*
add wave -group "Setup Control" test/setup/control/*
add wave -group "Setup Buffers DIn(0)" \
    test/setup/exchange/buffers/gen_dq(0)/data_in/*
add wave -group "Setup Buffers" test/setup/exchange/buffers/*
add wave -group "Setup Exchange" test/setup/exchange/*
add wave -group "Setup Delay" test/setup/delay/*
add wave -group "Setup" test/setup/*
add wave -group "Test" test/*
add wave -group "Bench" sim:*

quietly set NumericStdNoWarnings 1

run 3 us

# vim: set filetype=tcl:
