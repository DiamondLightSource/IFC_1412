# Builds test-gddr6_ip project using pre-built GDDR6 IP
set project_name $env(PROJECT_NAME)
set fpga_part $env(FPGA_PART)
set fpga_top $env(FPGA_TOP)
set ip_dir $env(IP_DIR)
set common_vhd $env(COMMON_VHD)
set vhd_dir $env(VHD_DIR)
set vhd_file_list $env(VHD_FILE_LIST)
set block_designs $env(BLOCK_DESIGNS)
set constr_files $env(CONSTR_FILES)
set constr_tcl $env(CONSTR_TCL)


# Prepare project to build netlist
create_project $project_name $project_name -part $fpga_part
set_param project.enableVHDL2008 1
set_property target_language VHDL [current_project]


# Add all the files listed in the source file
set infile [open $vhd_file_list]
while { [gets $infile line] >= 0 } {
    set newfile [add_files [subst $line]]
    set_property FILE_TYPE "VHDL 2008" $newfile
}
close $infile
set_property top top [current_fileset]

# Load the constraints
read_xdc $constr_files
add_files -fileset constrs_1 -norecurse $constr_tcl


# Add the GDDR6 IP to our project
set_property ip_repo_paths $ip_dir [current_project]

# Load and prepare the block design
foreach bd $block_designs {
    source $fpga_top/bd/$bd.tcl
    validate_bd_design
    make_wrapper -files [get_files $bd/$bd.bd] -top
    add_files -norecurse $bd/hdl/${bd}_wrapper.vhd
}

# Run the implementation
launch_runs impl_1 -to_step write_bitstream -jobs 6
wait_on_run impl_1
