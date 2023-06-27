# Reference clock
create_clock -period 10.0 -name SYSCLK100 [get_ports pad_SYSCLK100_P]
# FCLKA on MGT, a copy of SYSCLK100 above, but unknown phase
create_clock -period 10.0 -name FCLKA [get_ports pad_MGT224_REFCLK_P]

# Mark reset from logic to PCIe core as asynchronous to ensure Vivado doesn't
# try to incorrectly time it
set_false_path -from [get_cells clocking/perst_n_out_reg]

# The SG WCK pins don't come in on GC (global clock capable) pins, instead these
# are special QBC pins only for BITSLICE input clocking.  To measure their
# frequency we need to allow alternataive routing.
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets i_sg1_wck/O]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets i_sg2_wck/O]

# Define clocks for the three clocks we want to measure.
create_clock -period 3.33 -name SG12_CK [get_ports pad_SG12_CK_P]
create_clock -period 3.32 -name SG1_WCK [get_ports pad_SG1_WCK_P]
create_clock -period 3.31 -name SG2_WCK [get_ports pad_SG2_WCK_P]

# Set false path to all registers marked with this custom attribute.  This is
# generally only used with util/sync_bit.vhd
set_false_path -to \
    [get_cells -hierarchical -filter { false_path_to == "TRUE" }]

# Max delay constraint
set_max_delay 4 -datapath_only \
    -from [get_cells -hierarchical -filter { max_delay_from == "TRUE" }]
