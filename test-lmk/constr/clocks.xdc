# Reference clock
create_clock -period 10.0 -name SYSCLK100 [get_ports pad_SYSCLK100_P]
# FCLKA on MGT, a copy of SYSCLK100 above, but unknown phase
create_clock -period 10.0 -name FCLKA [get_ports pad_MGT224_REFCLK_P]

# Mark reset from logic to PCIe core as asynchronous to ensure Vivado doesn't
# try to incorrectly time it
set_false_path -from [get_cells clocking/perst_n_out_reg]
