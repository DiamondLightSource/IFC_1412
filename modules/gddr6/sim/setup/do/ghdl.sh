#!/usr/bin/env bash

HERE="$(dirname "$0")"
COMMON="$(sed -n '/^FPGA_COMMON *= */{s///;p}' "$HERE"/../../../../CONFIG)"

common_vhd="$COMMON"/vhd/
common_sim="$COMMON"/sim/common/
vhd_dir="$HERE"/../../../vhd/
bench_dir="$HERE"/../bench/

# Oops.  This doesn't work so well!
built_dir=/scratch/mga83/tmp/IFC_1412.pre/gddr6/sim/setup/built_dir/
built_dir=./

files=(
    $common_vhd/support.vhd
    $common_vhd/util/memory_array_dual.vhd
    $common_vhd/util/sync_bit.vhd
    $common_vhd/util/cross_clocks.vhd
    $common_vhd/util/cross_clocks_write.vhd
    $common_vhd/util/cross_clocks_write_read.vhd
    $common_vhd/util/memory_array.vhd
    $common_vhd/util/long_delay.vhd
    $common_vhd/util/fixed_delay_dram.vhd
    $common_vhd/util/fixed_delay.vhd
    $common_vhd/util/dlyreg.vhd
    $common_vhd/util/sync_pulse.vhd
    $common_vhd/util/edge_detect.vhd
    $common_vhd/util/cross_clocks_read.vhd
    $common_vhd/register/register_defs.vhd
    $common_vhd/register/register_command.vhd
    $common_vhd/register/register_bank_cc.vhd
    $common_vhd/register/register_cc.vhd
    $common_vhd/register/register_file_cc.vhd
    $common_vhd/register/register_file.vhd
    $common_vhd/register/register_file_rw.vhd
    $common_vhd/register/register_read_block.vhd
    $common_vhd/register/register_status.vhd
    $vhd_dir/gddr6_defs.vhd
    $built_dir/gddr6_register_defines.vhd
    $vhd_dir/setup/gddr6_setup_control.vhd
    $vhd_dir/setup/gddr6_setup_buffers.vhd
    $vhd_dir/setup/gddr6_setup_exchange.vhd
    $vhd_dir/setup/gddr6_setup_delay.vhd
    $vhd_dir/setup/gddr6_setup.vhd
    $common_sim/sim_support.vhd
    $bench_dir/testbench.vhd
)

# Connect to pc0034 for this to work
GHDL=~hir12111/.nix-profile/bin/ghdl

rm -f wave.ghw work-obj08.cf

# $GHDL -a --std=08 -frelaxed -Wno-hide -Wno-open-assoc -Wno-specs ${files[@]}  &&
# $GHDL -r --std=08 -frelaxed testbench \
#     --stop-time=1us --wave=wave.ghw --ieee-asserts=disable
$GHDL -a --std=08 -frelaxed -Wno-hide -Wno-open-assoc -Wno-specs ${files[@]}  &&
$GHDL -r --std=08 -frelaxed testbench \
    --stop-time=1us --wave=wave.ghw --ieee-asserts=disable
