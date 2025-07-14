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


# Creates configuration for SYS LMK.  The only option is whether to enable
# overclocking of the SGRAM; in this case the 125MHz outputs are disabled as
# they can no longer be generated.
def create_config(overclock):
    # The VCO runs at 6 GHz and is locked (via the intermediate frequency) to
    # the frequency doubled 100 MHz crystal.  For normal operation we use an
    # intermediate frequency of 2 GHz which can be divided by 2 and 8 for WCK
    # and CK at 1 GHz and 250 MHz respectively, and divided by 8 to generate a
    # 125 MHz reference clock.
    #   For overclocked operation the VCO is divided by 5 for an IF of 1.2 GHz,
    # yielding WCK/CK at 1.2 GHz and 300 MHz with divisors 1 and 4, but there is
    # no sensible reference clock available.

    class SysPll2Config(Pll2Config):
        double_r = True     # Reference at 100 MHz is doubled to 200 MHz
        prop = 37           # From IOxOS
        if overclock:
            d = 5           # IF = 6 GHz / 5 = 1.2 GHz
            n = 6           # IF / 6 = 200 MHz
        else:
            d = 3           # IF = 6 GHz / 3 = 2 GHz
            n = 10          # IF / 10 = 200 MHz

    class SysClock125Mhz(ClockOut):
        div = 16
        drv0 = 'HSDS4mA'
        drv1 = 'HSDS4mA'

    class SysClockCK(ClockOut):
        div = 4 if overclock else 8     # 300 MHz or 250 MHz
        drv0 = 'HSDS8mA'
        slew = 0

    class SysClockWCK(ClockOut):
        div = 1 if overclock else 2     # 1.2 GHz or 1 GHz
        drv0 = 'HSDS8mA'
        drv1 = 'HSDS8mA'
        slew = 0


    RefClk_outputs = [
        SysClock125Mhz, # 0: RTM CLK3 OUT
        SysClock125Mhz, # 2, 3: MGT 227, 229 for FMC1
        SysClock125Mhz, # 4, 5: MGC 127, 230
        SysClock125Mhz, # 6, 7: MGT 232, RTM CLK0 OUT
    ]
    CK_outputs = [
        SysClockWCK,    # 8, 9: WCK_A to SGRAM bank A and QBC bank 24
        SysClockWCK,    # 10, 11: WCK_B to SGRAM bank B and QBC bank 25
        SysClockCK,     # 12: CK to SGRAM
        SysClockCK,     # 14: CLK to GC bank 24
    ]

    class SysConfig(Config):
        oscin = True
        pll1 = None
        pll2 = SysPll2Config
        sync_ports = [4, 5, 6, 7]

        if overclock:
            outputs = 4 * [None] + CK_outputs
        else:
            outputs = RefClk_outputs + CK_outputs

    return SysConfig
