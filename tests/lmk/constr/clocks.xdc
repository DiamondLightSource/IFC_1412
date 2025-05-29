# Reference clock
create_clock -period 10.0 -name SYSCLK100 [get_ports pad_SYSCLK100_P]
# FCLKA on MGT, a copy of SYSCLK100 above, but unknown phase
create_clock -period 10.0 -name FCLKA [get_ports pad_MGT224_REFCLK_P]

# Mark reset from logic to PCIe core as asynchronous to ensure Vivado doesn't
# try to incorrectly time it
set_false_path -from [get_cells clocking/perst_n_out_reg]

# The SG WCK pins don't come in on GC (global clock capable) pins, instead these
# are special QBC pins only for BITSLICE input clocking.  To measure their
# frequency we need to allow alternative routing.
set_property CLOCK_DEDICATED_ROUTE FALSE \
    [get_nets {clock_inputs/sg/ibufds_array[0].ibufds_inst/O}]
set_property CLOCK_DEDICATED_ROUTE FALSE \
    [get_nets {clock_inputs/sg/ibufds_array[1].ibufds_inst/O}]

# Define clocks for the clocks we want to measure.
create_clock -period 2.0 [get_ports pad_SG12_CK_P]
create_clock -period 2.0 [get_ports pad_SG1_WCK_P]
create_clock -period 2.0 [get_ports pad_SG2_WCK_P]
create_clock -period 2.0 [get_ports pad_FPGA_ACQCLK_P]
create_clock -period 2.0 [get_ports pad_AMC_TCLKB_IN_P]
create_clock -period 2.0 [get_ports {pad_FMC1_CLK_P[0]}]
create_clock -period 2.0 [get_ports {pad_FMC1_CLK_P[1]}]
create_clock -period 2.0 [get_ports {pad_FMC1_CLK_P[2]}]
create_clock -period 2.0 [get_ports {pad_FMC1_CLK_P[3]}]
create_clock -period 2.0 [get_ports {pad_FMC2_CLK_P[0]}]
create_clock -period 2.0 [get_ports {pad_FMC2_CLK_P[1]}]
create_clock -period 2.0 [get_ports {pad_FMC2_CLK_P[2]}]
create_clock -period 2.0 [get_ports {pad_FMC2_CLK_P[3]}]
create_clock -period 2.0 [get_ports {pad_E10G_CLK1_P}]
create_clock -period 2.0 [get_ports {pad_E10G_CLK2_P}]
create_clock -period 2.0 [get_ports {pad_E10G_CLK3_P}]
create_clock -period 2.0 [get_ports {pad_MGT126_CLK0_P}]
create_clock -period 2.0 [get_ports {pad_MGT227_REFCLK_P}]
create_clock -period 2.0 [get_ports {pad_MGT229_REFCLK_P}]
create_clock -period 2.0 [get_ports {pad_MGT230_REFCLK_P}]
create_clock -period 2.0 [get_ports {pad_MGT127_REFCLK_P}]
create_clock -period 2.0 [get_ports {pad_MGT232_REFCLK_P}]
create_clock -period 2.0 [get_ports {pad_RTM_GTP_CLK0_IN_P}]
create_clock -period 2.0 [get_ports {pad_RTM_GTP_CLK3_IN_P}]
create_clock -period 2.0 [get_ports {pad_FMC1_GBTCLK_P[0]}]
create_clock -period 2.0 [get_ports {pad_FMC1_GBTCLK_P[1]}]
create_clock -period 2.0 [get_ports {pad_FMC1_GBTCLK_P[2]}]
create_clock -period 2.0 [get_ports {pad_FMC1_GBTCLK_P[3]}]
create_clock -period 2.0 [get_ports {pad_FMC2_GBTCLK_P[0]}]
create_clock -period 2.0 [get_ports {pad_FMC2_GBTCLK_P[1]}]
create_clock -period 2.0 [get_ports {pad_FMC2_GBTCLK_P[2]}]
create_clock -period 2.0 [get_ports {pad_FMC2_GBTCLK_P[3]}]
