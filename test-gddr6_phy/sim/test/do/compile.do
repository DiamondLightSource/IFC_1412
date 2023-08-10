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
    built_dir/register_defines.vhd \
    built_dir/version.vhd \
    $common_vhd/util/sync_reset.vhd \
    $common_vhd/util/sync_bit.vhd \
    $common_vhd/util/sync_pulse.vhd \
    $common_vhd/util/memory_array.vhd \
    $common_vhd/util/long_delay.vhd \
    $common_vhd/util/fixed_delay_dram.vhd \
    $common_vhd/util/fixed_delay.vhd \
    $common_vhd/util/dlyreg.vhd \
    $common_vhd/util/stretch_pulse.vhd \
    $common_vhd/util/cross_clocks.vhd \
    $common_vhd/util/cross_clocks_write.vhd \
    $common_vhd/util/cross_clocks_write_read.vhd \
    $common_vhd/register/register_defs.vhd \
    $common_vhd/register/register_buffer.vhd \
    $common_vhd/register/register_mux_strobe.vhd \
    $common_vhd/register/register_mux.vhd \
    $common_vhd/register/register_file.vhd \
    $common_vhd/register/register_file_rw.vhd \
    $common_vhd/register/register_events.vhd \
    $common_vhd/register/register_command.vhd \
    $common_vhd/register/register_bank_cc.vhd \
    $common_vhd/misc/spi_master.vhd \
    $common_vhd/iodefs/ibufds_array.vhd \
    $common_vhd/iodefs/ibuf_array.vhd \
    $common_vhd/iodefs/obuf_array.vhd \
    $common_vhd/iodefs/iobuf_array.vhd \
    $gddr6_dir/gddr6_config_defs.vhd \
    $gddr6_dir/phy/gddr6_phy_defs.vhd \
    $gddr6_dir/phy/gddr6_phy_io.vhd \
    $gddr6_dir/phy/gddr6_phy_clocking.vhd \
    $gddr6_dir/phy/gddr6_phy_ca.vhd \
    $gddr6_dir/phy/gddr6_phy_nibble.vhd \
    $gddr6_dir/phy/gddr6_phy_byte.vhd \
    $gddr6_dir/phy/gddr6_phy_map_data.vhd \
    $gddr6_dir/phy/gddr6_phy_bitslip.vhd \
    $gddr6_dir/phy/gddr6_phy_dq_remap.vhd \
    $gddr6_dir/phy/gddr6_phy_crc.vhd \
    $gddr6_dir/phy/gddr6_phy_dq.vhd \
    $gddr6_dir/phy/gddr6_phy_riu_control.vhd \
    $gddr6_dir/phy/gddr6_phy.vhd \
    $vhd_dir/decode_registers.vhd \
    $vhd_dir/system_registers.vhd \
    $vhd_dir/write_ca.vhd \
    $vhd_dir/gddr6_registers.vhd \
    $vhd_dir/lmk04616_io.vhd \
    $vhd_dir/lmk04616_control.vhd \
    $vhd_dir/lmk04616.vhd \
    $vhd_dir/test_gddr6_phy.vhd

vcom -64 -2008 -work xil_defaultlib \
    $common_sim/sim_support.vhd \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "SYS Mux" test_gddr6_phy/decode_registers/sys_register_mux/*
add wave -group "Decode" test_gddr6_phy/decode_registers/*
add wave -group "System Regs" test_gddr6_phy/system_registers/*
add wave -group "GDDR6 Regs" test_gddr6_phy/gddr6_registers/*
add wave -group "LMK" test_gddr6_phy/lmk04616/*
add wave -group "PHY" test_gddr6_phy/phy/*
add wave -group "Test" test_gddr6_phy/*
add wave -group "Bench" sim:*


run 500 ns

# vim: set filetype=tcl:
