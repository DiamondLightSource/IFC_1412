#!/usr/bin/env bash

HERE="$(dirname "$0")"
COMMON="$(sed -n '/^FPGA_COMMON *= */{s///;p}' "$HERE"/../../../../CONFIG)"

common_vhd="$COMMON"/vhd/
vhd_dir="$HERE"/../../../vhd/
bench_dir="$HERE"/../bench/


files=(
    $common_vhd/support.vhd
    $common_vhd/util/flow_control.vhd
    $common_vhd/util/sync_bit.vhd
    $common_vhd/util/fifo.vhd
    $common_vhd/util/short_delay.vhd
    $common_vhd/util/memory_array.vhd
    $common_vhd/util/memory_array_dual.vhd
    $common_vhd/util/memory_array_dual_bytes.vhd
    $common_vhd/util/long_delay.vhd
    $common_vhd/util/fixed_delay_dram.vhd
    $common_vhd/util/fixed_delay.vhd
    $common_vhd/util/stretch_pulse.vhd
    $common_vhd/async_fifo/async_fifo_address.vhd
    $common_vhd/async_fifo/async_fifo_reset.vhd
    $common_vhd/async_fifo/async_fifo.vhd
    $vhd_dir/gddr6_defs.vhd
    $vhd_dir/phy/gddr6_phy_crc.vhd
    $vhd_dir/ctrl/gddr6_ctrl_command_defs.vhd
    $vhd_dir/ctrl/gddr6_ctrl_defs.vhd
    $vhd_dir/ctrl/gddr6_ctrl_timing_defs.vhd
    $vhd_dir/ctrl/gddr6_ctrl_delay_defs.vhd
    $vhd_dir/ctrl/gddr6_ctrl_tuning_defs.vhd
    $vhd_dir/ctrl/gddr6_ctrl_read.vhd
    $vhd_dir/ctrl/gddr6_ctrl_write.vhd
    $vhd_dir/ctrl/gddr6_ctrl_lookahead.vhd
    $vhd_dir/ctrl/gddr6_ctrl_admin.vhd
    $vhd_dir/ctrl/gddr6_ctrl_refresh.vhd
    $vhd_dir/ctrl/gddr6_ctrl_bank.vhd
    $vhd_dir/ctrl/gddr6_ctrl_banks.vhd
    $vhd_dir/ctrl/gddr6_ctrl_mux.vhd
    $vhd_dir/ctrl/gddr6_ctrl_request.vhd
    $vhd_dir/ctrl/gddr6_ctrl_command.vhd
    $vhd_dir/ctrl/gddr6_ctrl_data.vhd
    $vhd_dir/ctrl/gddr6_ctrl_temps.vhd
    $vhd_dir/ctrl/gddr6_ctrl.vhd
    $vhd_dir/axi/gddr6_axi_defs.vhd
    $vhd_dir/axi/gddr6_axi_address.vhd
    $vhd_dir/axi/gddr6_axi_address_fifo.vhd
    $vhd_dir/axi/gddr6_axi_command_fifo.vhd
    $vhd_dir/axi/gddr6_axi_ctrl.vhd
    $vhd_dir/axi/gddr6_axi_read_data.vhd
    $vhd_dir/axi/gddr6_axi_read_data_fifo.vhd
    $vhd_dir/axi/gddr6_axi_read.vhd
    $vhd_dir/axi/gddr6_axi_write_response_fifo.vhd
    $vhd_dir/axi/gddr6_axi_write_response.vhd
    $vhd_dir/axi/gddr6_axi_write_data_fifo.vhd
    $vhd_dir/axi/gddr6_axi_write_status_fifo.vhd
    $vhd_dir/axi/gddr6_axi_write_data.vhd
    $vhd_dir/axi/gddr6_axi_write.vhd
    $vhd_dir/axi/gddr6_axi_stats.vhd
    $vhd_dir/axi/gddr6_axi.vhd
    $bench_dir/../../common/decode_commands.vhd
    $bench_dir/sim_phy_defs.vhd
    $bench_dir/sim_phy_memory.vhd
    $bench_dir/sim_phy_command.vhd
    $bench_dir/sim_phy.vhd
    $bench_dir/sim_axi_master.vhd
    $bench_dir/testbench.vhd
)

# Connect to pc0034 for this to work
GHDL=~hir12111/.nix-profile/bin/ghdl

rm -f wave.ghw work-obj08.cf

# -frelaxed converts attributes on ports from error to warning
# -Wno-specs suppresses this warning
# -Wno-hide suppresses a lot of annoying "hides entity" messages

$GHDL -a --std=08 -frelaxed -Wno-specs -Wno-hide ${files[@]}  &&
$GHDL -r --std=08 -frelaxed testbench \
    --stop-time=1us --wave=wave.ghw --ieee-asserts=disable
