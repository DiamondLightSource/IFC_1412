# Reference clock
create_clock -period 10.0 -name SYSCLK100 [get_ports pad_SYSCLK100_P]
# FCLKA on MGT, a copy of SYSCLK100 above, but unknown phase
create_clock -period 10.0 -name FCLKA [get_ports pad_MGT224_REFCLK_P]


# Set routing delay constraints on the four STARTUPE3 connections as recommended
# by Xilinx note 000034704
set setup_delay 0.5

# fpga_clk -> USRCCLKO
set_max_delay -datapath_only \
    -from [get_cells flash/io/fpga_clk_reg] \
    -to [get_pins flash/io/startup/USRCCLKO] $setup_delay

# spi_cs_n -> FCSBO
set_max_delay -datapath_only \
    -from [get_cells {flash/io/spi_cs_n_reg[*]}] \
    -to [get_pins flash/io/startup/FCSBO] $setup_delay

# mosi -> DO
set_max_delay -datapath_only \
    -from [get_cells {flash/io/mosi_reg[*]}] \
    -to [get_pins flash/io/startup/DO] $setup_delay

# DTS -> DI
set_max_delay -datapath_only \
    -from [get_pins flash/io/startup/DI] \
    -to [get_cells {flash/io/miso_reg[*]}] $setup_delay

