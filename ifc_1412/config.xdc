#---------------------------------------------------------------------------
# Configuration Bank
#---------------------------------------------------------------------------
#
set_property CONFIG_MODE SPIx8                      [current_design]
set_property CONFIG_VOLTAGE 2.5                     [current_design]
set_property CFGBVS VCCO                            [current_design]

set_property BITSTREAM.CONFIG.USR_ACCESS TIMESTAMP  [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50         [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE        [current_design]
