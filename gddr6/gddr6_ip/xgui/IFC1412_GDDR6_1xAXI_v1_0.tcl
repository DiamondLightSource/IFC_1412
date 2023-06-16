# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "g_axigddr6_READ" -parent ${Page_0}
  ipgui::add_param $IPINST -name "g_axigddr6_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "g_axigddr6_WRITE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "g_axigddr6_WSIZ" -parent ${Page_0}


}

proc update_PARAM_VALUE.g_axigddr6_READ { PARAM_VALUE.g_axigddr6_READ } {
	# Procedure called to update g_axigddr6_READ when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.g_axigddr6_READ { PARAM_VALUE.g_axigddr6_READ } {
	# Procedure called to validate g_axigddr6_READ
	return true
}

proc update_PARAM_VALUE.g_axigddr6_WIDTH { PARAM_VALUE.g_axigddr6_WIDTH } {
	# Procedure called to update g_axigddr6_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.g_axigddr6_WIDTH { PARAM_VALUE.g_axigddr6_WIDTH } {
	# Procedure called to validate g_axigddr6_WIDTH
	return true
}

proc update_PARAM_VALUE.g_axigddr6_WRITE { PARAM_VALUE.g_axigddr6_WRITE } {
	# Procedure called to update g_axigddr6_WRITE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.g_axigddr6_WRITE { PARAM_VALUE.g_axigddr6_WRITE } {
	# Procedure called to validate g_axigddr6_WRITE
	return true
}

proc update_PARAM_VALUE.g_axigddr6_WSIZ { PARAM_VALUE.g_axigddr6_WSIZ } {
	# Procedure called to update g_axigddr6_WSIZ when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.g_axigddr6_WSIZ { PARAM_VALUE.g_axigddr6_WSIZ } {
	# Procedure called to validate g_axigddr6_WSIZ
	return true
}


proc update_MODELPARAM_VALUE.g_axigddr6_WSIZ { MODELPARAM_VALUE.g_axigddr6_WSIZ PARAM_VALUE.g_axigddr6_WSIZ } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.g_axigddr6_WSIZ}] ${MODELPARAM_VALUE.g_axigddr6_WSIZ}
}

proc update_MODELPARAM_VALUE.g_axigddr6_WIDTH { MODELPARAM_VALUE.g_axigddr6_WIDTH PARAM_VALUE.g_axigddr6_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.g_axigddr6_WIDTH}] ${MODELPARAM_VALUE.g_axigddr6_WIDTH}
}

proc update_MODELPARAM_VALUE.g_axigddr6_READ { MODELPARAM_VALUE.g_axigddr6_READ PARAM_VALUE.g_axigddr6_READ } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.g_axigddr6_READ}] ${MODELPARAM_VALUE.g_axigddr6_READ}
}

proc update_MODELPARAM_VALUE.g_axigddr6_WRITE { MODELPARAM_VALUE.g_axigddr6_WRITE PARAM_VALUE.g_axigddr6_WRITE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.g_axigddr6_WRITE}] ${MODELPARAM_VALUE.g_axigddr6_WRITE}
}

