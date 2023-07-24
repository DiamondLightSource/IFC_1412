# Reference clock
create_clock -period 10.0 -name SYSCLK100 [get_ports pad_SYSCLK100_P]
# FCLKA on MGT, a copy of SYSCLK100 above, but unknown phase
create_clock -period 10.0 -name FCLKA [get_ports pad_MGT224_REFCLK_P]

# Define clocks for the three SG clocks, CK running at 300MHz and WCK at 1.2GHz
create_clock -period 4.0 -name SG12_CK [get_ports pad_SG12_CK_P]
create_clock -period 1.0 -name SG1_WCK [get_ports pad_SG1_WCK_P]
create_clock -period 1.0 -name SG2_WCK [get_ports pad_SG2_WCK_P]

# Let the incoming CK BUFG use the vertical backbone
set_property CLOCK_DEDICATED_ROUTE SAME_CMT_COLUMN \
    [get_nets -of [get_pins phy/clocking/bufg_in/O]]

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
