# The maximum sensible CK frequency seems to be around 250 MHz
set ck_frequency 250.0

# Reference clock
create_clock -period 10.0 -name SYSCLK100 [get_ports pad_SYSCLK100_P]
# FCLKA on MGT, a copy of SYSCLK100 above, but unknown phase
create_clock -period 10.0 -name FCLKA [get_ports pad_MGT224_REFCLK_P]

# Define clocks for the three SG clocks, CK and WCK at 4 * CK frequency
create_clock -period [expr 1e3 / $ck_frequency] \
    -name SG12_CK [get_ports pad_SG12_CK_P]
create_clock -period [expr 1e3 / $ck_frequency / 4] \
    -name SG1_WCK [get_ports pad_SG1_WCK_P]
create_clock -period [expr 1e3 / $ck_frequency / 4] \
    -name SG2_WCK [get_ports pad_SG2_WCK_P]


# Set false path to all registers marked with this custom attribute.  This is
# generally only used with util/sync_bit.vhd
set_false_path -to \
    [get_cells -hierarchical -filter { false_path_to == "TRUE" }]

# Similarly for from attributes, needed for reset registers.
set_false_path -from \
    [get_cells -hierarchical -filter { false_path_from == "TRUE" }]

# Max delay constraint
set_max_delay 4 -datapath_only \
    -from [get_cells -hierarchical -filter { max_delay_from == "TRUE" }]

# vim: set filetype=tcl:
