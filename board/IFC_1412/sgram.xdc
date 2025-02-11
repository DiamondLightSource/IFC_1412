# Special settings for SGRAM IO pins

set_property DCI_CASCADE {24} [get_iobanks 25]

set_property UNAVAILABLE_DURING_CALIBRATION TRUE [get_ports {pad_SG12_CAL[0]}];
set_property UNAVAILABLE_DURING_CALIBRATION TRUE [get_ports {pad_SG12_CAL[1]}];
set_property UNAVAILABLE_DURING_CALIBRATION TRUE [get_ports {pad_SG12_CAL[2]}];
set_property UNAVAILABLE_DURING_CALIBRATION TRUE [get_ports {pad_SG12_CAU[7]}];
