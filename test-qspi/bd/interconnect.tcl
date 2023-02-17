
################################################################
# This is a generated script based on design: interconnect
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2022.2
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   catch {common::send_gid_msg -ssname BD::TCL -id 2041 -severity "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   return 1
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source interconnect_script.tcl

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xcku085-flva1517-1-c
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name interconnect

# This script was generated for a remote BD. To create a non-remote design,
# change the variable <run_remote_bd_flow> to <0>.

set run_remote_bd_flow 1
if { $run_remote_bd_flow == 1 } {
  # Set the reference directory for source file relative paths (by default 
  # the value is script directory path)
  set origin_dir .

  # Use origin directory path location variable, if specified in the tcl shell
  if { [info exists ::origin_dir_loc] } {
     set origin_dir $::origin_dir_loc
  }

  set str_bd_folder [file normalize ${origin_dir}]
  set str_bd_filepath ${str_bd_folder}/${design_name}/${design_name}.bd

  # Check if remote design exists on disk
  if { [file exists $str_bd_filepath ] == 1 } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2030 -severity "ERROR" "The remote BD file path <$str_bd_filepath> already exists!"}
     common::send_gid_msg -ssname BD::TCL -id 2031 -severity "INFO" "To create a non-remote BD, change the variable <run_remote_bd_flow> to <0>."
     common::send_gid_msg -ssname BD::TCL -id 2032 -severity "INFO" "Also make sure there is no design <$design_name> existing in your current project."

     return 1
  }

  # Check if design exists in memory
  set list_existing_designs [get_bd_designs -quiet $design_name]
  if { $list_existing_designs ne "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2033 -severity "ERROR" "The design <$design_name> already exists in this project! Will not create the remote BD <$design_name> at the folder <$str_bd_folder>."}

     common::send_gid_msg -ssname BD::TCL -id 2034 -severity "INFO" "To create a non-remote BD, change the variable <run_remote_bd_flow> to <0> or please set a different value to variable <design_name>."

     return 1
  }

  # Check if design exists on disk within project
  set list_existing_designs [get_files -quiet */${design_name}.bd]
  if { $list_existing_designs ne "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2035 -severity "ERROR" "The design <$design_name> already exists in this project at location:
    $list_existing_designs"}
     catch {common::send_gid_msg -ssname BD::TCL -id 2036 -severity "ERROR" "Will not create the remote BD <$design_name> at the folder <$str_bd_folder>."}

     common::send_gid_msg -ssname BD::TCL -id 2037 -severity "INFO" "To create a non-remote BD, change the variable <run_remote_bd_flow> to <0> or please set a different value to variable <design_name>."

     return 1
  }

  # Now can create the remote BD
  # NOTE - usage of <-dir> will create <$str_bd_folder/$design_name/$design_name.bd>
  create_bd_design -dir $str_bd_folder $design_name
} else {

  # Create regular design
  if { [catch {create_bd_design $design_name} errmsg] } {
     common::send_gid_msg -ssname BD::TCL -id 2038 -severity "INFO" "Please set a different value to variable <design_name>."

     return 1
  }
}

current_bd_design $design_name

set bCheckIPsPassed 1
##################################################################
# CHECK IPs
##################################################################
set bCheckIPs 1
if { $bCheckIPs == 1 } {
   set list_check_ips "\ 
xilinx.com:ip:axi_bram_ctrl:4.1\
xilinx.com:ip:axi_pcie3:3.0\
xilinx.com:ip:axi_quad_spi:3.2\
xilinx.com:ip:blk_mem_gen:8.4\
xilinx.com:ip:util_ds_buf:2.2\
"

   set list_ips_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2012 -severity "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

}

if { $bCheckIPsPassed != 1 } {
  common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 3
}

##################################################################
# DESIGN PROCs
##################################################################



# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports
  set FCLKA [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 FCLKA ]

  set USER_SPI [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:spi_rtl:1.0 USER_SPI ]

  set pcie_7x_mgt_0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:pcie_7x_mgt_rtl:1.0 pcie_7x_mgt_0 ]


  # Create ports
  set EXT_SPI_CLK [ create_bd_port -dir I -type clk -freq_hz 100000000 EXT_SPI_CLK ]
  set nCOLDRST [ create_bd_port -dir I -type rst nCOLDRST ]

  # Create instance: axi_bram_ctrl_0, and set properties
  set axi_bram_ctrl_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0 ]
  set_property -dict [list \
    CONFIG.PROTOCOL {AXI4LITE} \
    CONFIG.SINGLE_PORT_BRAM {1} \
  ] $axi_bram_ctrl_0


  # Create instance: axi_lite_interconnect, and set properties
  set axi_lite_interconnect [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_lite_interconnect ]
  set_property CONFIG.NUM_MI {2} $axi_lite_interconnect


  # Create instance: axi_pcie3_bridge, and set properties
  set axi_pcie3_bridge [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_pcie3:3.0 axi_pcie3_bridge ]
  set_property -dict [list \
    CONFIG.axi_addr_width {48} \
    CONFIG.axi_data_width {64_bit} \
    CONFIG.axisten_freq {125} \
    CONFIG.dedicate_perst {false} \
    CONFIG.disable_gt_loc {true} \
    CONFIG.en_axi_slave_if {false} \
    CONFIG.en_gt_selection {true} \
    CONFIG.ins_loss_profile {Backplane} \
    CONFIG.mode_selection {Advanced} \
    CONFIG.pciebar2axibar_0 {0x0000000000010000} \
    CONFIG.pciebar2axibar_2 {0x0000000000020000} \
    CONFIG.pf0_Use_Class_Code_Lookup_Assistant {false} \
    CONFIG.pf0_bar0_64bit {true} \
    CONFIG.pf0_bar0_size {64} \
    CONFIG.pf0_bar2_64bit {true} \
    CONFIG.pf0_bar2_enabled {true} \
    CONFIG.pf0_bar2_size {64} \
    CONFIG.pf0_base_class_menu {Processors} \
    CONFIG.pf0_class_code_base {11} \
    CONFIG.pf0_class_code_sub {80} \
    CONFIG.pf0_device_id {7038} \
    CONFIG.pf0_interrupt_pin {NONE} \
    CONFIG.pf0_sub_class_interface_menu {386} \
    CONFIG.pl_link_cap_max_link_speed {2.5_GT/s} \
    CONFIG.pl_link_cap_max_link_width {X4} \
    CONFIG.select_quad {GTH_Quad_224} \
    CONFIG.sys_reset_polarity {ACTIVE_LOW} \
  ] $axi_pcie3_bridge


  # Create instance: axi_quad_spi_0, and set properties
  set axi_quad_spi_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_quad_spi:3.2 axi_quad_spi_0 ]
  set_property -dict [list \
    CONFIG.C_FIFO_DEPTH {256} \
    CONFIG.C_SPI_MEMORY {3} \
    CONFIG.C_SPI_MODE {2} \
  ] $axi_quad_spi_0


  # Create instance: blk_mem_gen_0, and set properties
  set blk_mem_gen_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 blk_mem_gen_0 ]
  set_property -dict [list \
    CONFIG.Coe_File {../../../built/metadata.coe} \
    CONFIG.Load_Init_File {true} \
    CONFIG.Memory_Type {Single_Port_ROM} \
    CONFIG.Port_A_Write_Rate {0} \
  ] $blk_mem_gen_0


  # Create instance: fclka_buf, and set properties
  set fclka_buf [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 fclka_buf ]
  set_property CONFIG.C_BUF_TYPE {IBUFDSGTE} $fclka_buf


  # Create interface connections
  connect_bd_intf_net -intf_net CLK_IN_D_0_1 [get_bd_intf_ports FCLKA] [get_bd_intf_pins fclka_buf/CLK_IN_D]
  connect_bd_intf_net -intf_net axi_bram_ctrl_0_BRAM_PORTA [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA] [get_bd_intf_pins blk_mem_gen_0/BRAM_PORTA]
  connect_bd_intf_net -intf_net axi_lite_interconnect_M00_AXI [get_bd_intf_pins axi_bram_ctrl_0/S_AXI] [get_bd_intf_pins axi_lite_interconnect/M00_AXI]
  connect_bd_intf_net -intf_net axi_lite_interconnect_M01_AXI [get_bd_intf_pins axi_lite_interconnect/M01_AXI] [get_bd_intf_pins axi_quad_spi_0/AXI_LITE]
  connect_bd_intf_net -intf_net axi_pcie3_bridge_M_AXI [get_bd_intf_pins axi_lite_interconnect/S00_AXI] [get_bd_intf_pins axi_pcie3_bridge/M_AXI]
  connect_bd_intf_net -intf_net axi_pcie3_bridge_pcie_7x_mgt [get_bd_intf_ports pcie_7x_mgt_0] [get_bd_intf_pins axi_pcie3_bridge/pcie_7x_mgt]
  connect_bd_intf_net -intf_net axi_quad_spi_0_SPI_0 [get_bd_intf_ports USER_SPI] [get_bd_intf_pins axi_quad_spi_0/SPI_0]

  # Create port connections
  connect_bd_net -net axi_pcie3_bridge_axi_aclk [get_bd_pins axi_bram_ctrl_0/s_axi_aclk] [get_bd_pins axi_lite_interconnect/ACLK] [get_bd_pins axi_lite_interconnect/M00_ACLK] [get_bd_pins axi_lite_interconnect/S00_ACLK] [get_bd_pins axi_pcie3_bridge/axi_aclk]
  connect_bd_net -net axi_pcie3_bridge_axi_aresetn [get_bd_pins axi_bram_ctrl_0/s_axi_aresetn] [get_bd_pins axi_lite_interconnect/ARESETN] [get_bd_pins axi_lite_interconnect/M00_ARESETN] [get_bd_pins axi_lite_interconnect/S00_ARESETN] [get_bd_pins axi_pcie3_bridge/axi_aresetn]
  connect_bd_net -net ext_spi_clk_0_1 [get_bd_ports EXT_SPI_CLK] [get_bd_pins axi_lite_interconnect/M01_ACLK] [get_bd_pins axi_quad_spi_0/ext_spi_clk] [get_bd_pins axi_quad_spi_0/s_axi_aclk]
  connect_bd_net -net fclka_buf_IBUF_DS_ODIV2 [get_bd_pins axi_pcie3_bridge/refclk] [get_bd_pins fclka_buf/IBUF_DS_ODIV2]
  connect_bd_net -net fclka_buf_IBUF_OUT [get_bd_pins axi_pcie3_bridge/sys_clk_gt] [get_bd_pins fclka_buf/IBUF_OUT]
  connect_bd_net -net nCOLDRST_1 [get_bd_ports nCOLDRST] [get_bd_pins axi_lite_interconnect/M01_ARESETN] [get_bd_pins axi_pcie3_bridge/sys_rst_n] [get_bd_pins axi_quad_spi_0/s_axi_aresetn]

  # Create address segments
  assign_bd_address -offset 0x00022000 -range 0x00001000 -target_address_space [get_bd_addr_spaces axi_pcie3_bridge/M_AXI] [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0] -force
  assign_bd_address -offset 0x00010000 -range 0x00001000 -target_address_space [get_bd_addr_spaces axi_pcie3_bridge/M_AXI] [get_bd_addr_segs axi_quad_spi_0/AXI_LITE/Reg] -force


  # Restore current instance
  current_bd_instance $oldCurInst

  validate_bd_design
  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""


