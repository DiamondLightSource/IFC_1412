# Reference clock
create_clock -period 10.0 -name SYSCLK100 [get_ports pad_SYSCLK100_P]
# FCLKA on MGT, a copy of SYSCLK100 above, but unknown phase
create_clock -period 10.0 -name FCLKA [get_ports pad_MGT224_REFCLK_P]

# Tell Vivado that timing between these two clocks is a mug's game
set_clock_groups -asynchronous \
    -group [get_clocks -include_generated_clocks SYSCLK100] \
    -group [get_clocks -include_generated_clocks FCLKA]
