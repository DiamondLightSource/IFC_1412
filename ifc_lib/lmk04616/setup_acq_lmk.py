# Initialisation of ACQ LMK

# Configuring the ACQ LMK can be a more complex process than the SYS LMK because
# there are far more open options available.
#
# Inputs can be selected from the following sources:
#
#   CLKIN0  <= Front panel connector
#   CLKIN1  <= AMC TCLKA
#   CLKIN2  <= AMC TCLKC
#   CLKIN3  <= FMC clock multiplexer, one of FMC{1,2}_CLK{0,1} or RTM_CLK_OUT
#   OSCIN   <= VCXO
#
# The OSCIN inputs can be passed through a divider and locked to the VCXO via
# PLL1 or PLL1 can be bypassed.  Similarly, PLL2 can be bypassed or configured,
# and the feedback paths can configured in a variety of modes.
#
# Outputs go to the following destinations:
#
#   CLKOUT0  => ACQCLK to FPGA
#   CLKOUT1  => (unused)
#   CLKOUT2  => RTM_CLK_IN
#   CLKOUT3  => (unused)
#   CLKOUT4  => RTM_TCLK_IN
#   CLKOUT5  => (unused)
#   CLKOUT6  => AMC TCLKB (if TCLKB switch set for output)
#   CLKOUT7  => AMC TCLKD
#   CLKOUT8  => FPGA FMC1_CLK2 (if FMC1 clocks configured for input)
#   CLKOUT9  => FMC1 FMC1_CLK2 (if FMC1 clocks configured for input)
#   CLKOUT10 => FPGA FMC2_CLK2 (if FMC2 clocks configured for input)
#   CLKOUT11 => FMC2 FMC2_CLK2 (if FMC2 clocks configured for input)
#   CLKOUT12 => FPGA and FMC1 FMC1_CLK3 (if FMC1 clocks configured for input)
#   CLKOUT13 => FPGA and FMC2 FMC2_CLK3 (if FMC2 clocks configured for input)
#   CLKOUT14 => FMC1 REFCLK_C2M_P if FMC1 REFCLK switch configured
#   CLKOUT15 => FMC2 REFCLK_C2M_P if FMC2 REFCLK switch configured

import os
import numpy
import time
import argparse

from .setup_lmk import *


class Pll1(Pll1Config):
    r = 300
    n = 100

class Output(ClockOut):
    div = 1
    drv0 = 'HSDS8mA'
    drv1 = 'HSDS8mA'
    slew = 0

Sources = {
    # Selections for CLKIN
    'ssmc' : 0,     # Front panel connector
    'tclka' : 1,    # TCLKA from AMC connector
    'tclkc' : 2,    # TCLKC from AMC connector
    'mux' : 3,      # FMC clock multiplexer
}


def create_config(source = 'ssmc', vcxo = False):
    # Currently the VCXO PLL is not supported; this will be a challenge!

    class AcqConfig(Config):
        clkin = Sources[source]
        outputs = 8 * [Output]
        oscin = vcxo

    return AcqConfig
