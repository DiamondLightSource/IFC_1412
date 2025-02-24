# Initialisation of SYS LMK

import time

from .setup_lmk import *


# The SYS LMK drives the following outputs:
#
#   CLKOUT0  @ 125 MHz  => RTM GTP CLK3 OUT
#   CLKOUT1  @ 125 MHz  => (unused)
#   CLKOUT2  @ 125 MHz  => MGT 227 for FMC1
#   CLKOUT3  @ 125 MHz  => MGT 229 for FMC1
#   CLKOUT4  @ 125 MHz  => MGT 127 for FMC2
#   CLKOUT5  @ 125 MHz  => MGT 230 for FMC2
#   CLKOUT6  @ 125 MHz  => MGT 232 for RTM GTP 3-0
#   CLKOUT7  @ 125 MHz  => RTM GTP CLK0 OUT
#   CLKOUT8  @ 1 GHz    => WCK_A to GDDR
#   CLKOUT9  @ 1 GHz    => WCK_A to bank 24 QBC
#   CLKOUT10 @ 1 GHz    => WCK_B to GDDR
#   CLKOUT11 @ 1 GHz    => WCK_B to bank 25 QBC
#   CLKOUT12 @ 250 MHz  => CK to GDDR
#   CLKOUT13            => (unused)
#   CLKOUT14 @ 250 MHz  => CK to bank 24 GC
#   CLKOUT15            => (unused)

# VCO runs at 6GHz with 2GHz intermediate frequency locked to 100MHz crystal
class SysPll2Config(Pll2Config):
    d = 3
    double_r = True
    n = 10
    prop = 37           # From IOxOS

class SysClock125Mhz(ClockOut):
    div = 16
    drv0 = 'HSDS4mA'
    drv1 = 'HSDS4mA'

class SysClockCK(ClockOut):
    div = 8
    drv0 = 'HSDS8mA'
    slew = 0

class SysClockWCK(ClockOut):
    div = 2
    drv0 = 'HSDS8mA'
    drv1 = 'HSDS8mA'
    slew = 0

SysClockConfig = [
    SysClock125Mhz, # 0: RTM CLK3 OUT
    SysClock125Mhz, # 2, 3: MGT 227, 229 for FMC1
    SysClock125Mhz, # 4, 5: MGC 127, 230
    SysClock125Mhz, # 6, 7: MGT 232, RTM CLK0 OUT
    SysClockWCK,    # 8, 9: WCK_A to SGRAM bank A and QBC bank 24
    SysClockWCK,    # 10, 11: WCK_B to SGRAM bank B and QBC bank 25
    SysClockCK,     # 12: CK to SGRAM
    SysClockCK,     # 14: CLK to GC bank 24
]

class SysConfig(Config):
    oscin = True
    pll1 = None
    pll2 = SysPll2Config
    outputs = SysClockConfig
    sync_ports = [4, 5, 6, 7]



class SysPll2Config300(Pll2Config):
    d = 5
    double_r = True
    n = 6
    prop = 37

class SysClockCK300(ClockOut):
    div = 4
    drv0 = 'HSDS8mA'
    slew = 0

class SysClockWCK300(ClockOut):
    div = 1
    drv0 = 'HSDS8mA'
    drv1 = 'HSDS8mA'
    slew = 0

SysClockConfig300 = [
    None,
    None,
    None,
    None,
    SysClockWCK300,    # 8, 9: WCK_A to SGRAM bank A and QBC bank 24
    SysClockWCK300,    # 10, 11: WCK_B to SGRAM bank B and QBC bank 25
    SysClockCK300,     # 12: CK to SGRAM
    SysClockCK300,     # 14: CLK to GC bank 24
]


# Special 300 MHz configuration with 1.2GHz intermediate frequency
class SysConfig300(SysConfig):
    pll2 = SysPll2Config300
    outputs = SysClockConfig300

CONFIGS = {
    '250' : SysConfig,
    '300' : SysConfig300,
}

def setup_sys_lmk(_lmk, config = '250'):
    if isinstance(config, str):
        config = CONFIGS[config]
    return setup_lmk(_lmk, config)
