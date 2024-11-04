# Create IP

set project_name $env(PROJECT_NAME)
set fpga_part $env(FPGA_PART)

set fpga_top $env(FPGA_TOP)
set vhd_dir $env(VHD_DIR)
set common_vhd $env(COMMON_VHD)

set ip_dir $env(IP_DIR)
set ip_version $env(IP_VERSION)


# Prepare project to build netlist
create_project $project_name $project_name -part $fpga_part
set_param project.enableVHDL2008 1
set_property target_language VHDL [current_project]


# Add all the files listed in the source file
set infile [open $fpga_top/gddr6-ip-files]
while { [gets $infile line] >= 0 } {
    set newfile [add_files [subst $line]]
    set_property FILE_TYPE "VHDL 2008" $newfile
}
close $infile
set_property top gddr6_ip_netlist [current_fileset]


# Build the design and write the netlist
synth_design -flatten_hierarchy rebuilt -mode out_of_context
write_checkpoint -force post_synth
write_edif $ip_dir/gddr6_ip/src/gddr6_ip_netlist.edn


# Now prepare the IP.  First we need the interface definitions
set_property ip_repo_paths $ip_dir [current_project]
ipx::infer_core -vendor diamond.ac.uk -library user -taxonomy /UserIP \
    -version $ip_version $ip_dir/gddr6_ip
