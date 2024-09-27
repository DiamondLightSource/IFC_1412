# we can operate at either 250 or 300 MHz, but 300 MHz needs a number of
# carefuly adjustments elsewhere
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

# vim: set filetype=tcl:
