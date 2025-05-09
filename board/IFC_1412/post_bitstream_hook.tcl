# Adds hook for building configuration files from bitstream

set board_dir $::env(BOARD_DIR)
set make_config [add_files $board_dir/post_bitstream.tcl -fileset utils_1]
set_property STEPS.WRITE_BITSTREAM.TCL.POST $make_config [get_runs impl_1]
