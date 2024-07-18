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
    [get_nets {sg_clocks/ibufds_array[0].ibufds_inst/O}]
set_property CLOCK_DEDICATED_ROUTE FALSE \
    [get_nets {sg_clocks/ibufds_array[1].ibufds_inst/O}]

# Define clocks for the clocks we want to measure.
create_clock -period 2.0 -name SG12_CK [get_ports pad_SG12_CK_P]
create_clock -period 2.0 -name SG1_WCK [get_ports pad_SG1_WCK_P]
create_clock -period 2.0 -name SG2_WCK [get_ports pad_SG2_WCK_P]
create_clock -period 2.0 -name ACQCLK [get_ports pad_FPGA_ACQCLK_P]
create_clock -period 2.0 -name TCLKB [get_ports pad_AMC_TCLKB_IN_P]
