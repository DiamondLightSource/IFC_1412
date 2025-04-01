# Special settings for SGRAM IO pins

set_property DCI_CASCADE {24} [get_iobanks 25]

set_property UNAVAILABLE_DURING_CALIBRATION TRUE [get_ports {pad_SG12_CAL[0]}];
set_property UNAVAILABLE_DURING_CALIBRATION TRUE [get_ports {pad_SG12_CAL[1]}];
set_property UNAVAILABLE_DURING_CALIBRATION TRUE [get_ports {pad_SG12_CAL[2]}];
set_property UNAVAILABLE_DURING_CALIBRATION TRUE [get_ports {pad_SG12_CAU[7]}];

set_property INTERNAL_VREF 0.84 [get_iobanks 24]
set_property INTERNAL_VREF 0.84 [get_iobanks 25]


# Gather names for setting attributes on all CA and DQ pins
# All the settings below are provided by IOxOS
set ca_pins [get_ports {
    pad_SG12_CABI_N pad_SG12_CKE_N {pad_SG*_CA3_*} {pad_SG12_CA*[*]}}]
set dq_pins [get_ports {
    {pad_SG*_DQ_*[*]} {pad_SG*_DBI_N_*[*]} {pad_SG*_EDC_*[*]}}]


set_property ODT RTT_40 $dq_pins

set_property OUTPUT_IMPEDANCE RDRV_40_40 $ca_pins
set_property OUTPUT_IMPEDANCE RDRV_40_40 $dq_pins

set_property PRE_EMPHASIS RDRV_240 $dq_pins

set_property SLEW FAST $dq_pins
set_property SLEW MEDIUM $ca_pins

# vim: set filetype=tcl:
