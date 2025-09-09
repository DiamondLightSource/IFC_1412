# Create IP from project

set project $env(_PROJECT)
set ip_dir_out $env(IP_DIR_OUT)
set ip_version $env(IP_VERSION)


open_project $project

# Add constraints to try and help with clock alignment
add_files -fileset constrs_1 $ip_dir_out/gddr6_ip/constr

# Build the design and write the netlist
synth_design -flatten_hierarchy rebuilt -mode out_of_context
write_checkpoint -force post_synth
write_edif $ip_dir_out/gddr6_ip/src/gddr6_ip_netlist.edn

# Now prepare the IP.  First we need the interface definitions
set_property ip_repo_paths $ip_dir_out [current_project]
ipx::infer_core -vendor diamond.ac.uk -library user -taxonomy /UserIP \
    -version $ip_version $ip_dir_out/gddr6_ip
