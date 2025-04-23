# Module for configuring system LMK

import time
from typing import Optional, List

from fpga_lib.devices import LMK04616


__all__ = []

# Adds given value to list of exports, ie default import * list
def export(value):
    __all__.append(value.__name__)
    return value


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Configuration settings, all marked for export

@export
class Pll1Config:
    '''Configuration settings for PLL1'''
    # Reference clock divider
    r : int = 1
    # Feedback clock divider
    n : int = 1
    # Proportional gain, set to default
    prop : int = 8
    # Integral gain
    intg : int = 1

@export
class Pll2Config:
    '''Configuration settings for PLL2'''
    # Selects whether to double the reference clock
    double_r : bool = False

    # Prescaler output, must be in range 3 to 6
    d : int = 3
    # Reference clock divider.  Ignored if double_r is set
    r : int = 1
    # Feedback clock divider
    n : int = 1
    # Proportional gain, set to default
    prop : int = 3
    cprop : int = 0
    # Integral gain
    intg : int = 3

@export
class ClockOut:
    '''Configuration settings for clock output pair'''
    # Common output divider
    div : int = 1
    # Drive levels for the outputs, see configure_clock_output below for options
    drv0 : str = 'off'
    drv1 : str = 'off'
    # Slew rate
    slew : int = 1

@export
class Config:
    clkin : Optional[int] = None
    oscin : bool = False
    pll1 : Optional[Pll1Config] = None
    pll2 : Optional[Pll2Config] = None
    outputs : List[ClockOut] = []
    sync_ports : List[int] = []


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Helper LMK setup functions


# Common LMK configuration setting
def configure_lmk_common(lmk):
    # First ensure we are in SPI 3-wire mode
    lmk.SPI_EN_THREE_WIRE_IF = 1    # Use SDIO for input and output

    # Put the PLL lock status on STATUS0 and STATUS1
    lmk.STATUS0_MUX_SEL = 4
    lmk.STATUS0_INT_MUX = 2         # PLL2 lock detect on STATUS0
    lmk.STATUS0_OUTPUT_HIZ = 0      # Ensure output is driven
    lmk.STATUS1_MUX_SEL = 4
    lmk.STATUS1_INT_MUX = 1         # PLL1 lock detect on STATUS1
    lmk.STATUS1_OUTPUT_HIZ = 0      # Ensure output is driven

    # Not using OSCOUT so can disable
    lmk.OSCOUT_DRV_MODE = 0         # Power down OSCOUT, not connected
    lmk.OSCIN_BUF_TO_OSCOUT_EN = 0  # Don't need this buffer

    lmk.PLL2_DUAL_LOOP_EN = 3       # Looks like this needs to be set

    # Reset lock detect windows.  Not sure what this is about
    lmk.PLL1_LD_WNDW_SIZE = 0       # Needs to be cleared from reset state
    lmk.PLL2_LD_WNDW_SIZE = 0       # Needs to be cleared from reset state
    lmk.PLL2_LD_WNDW_SIZE_INITIAL = 0   # as does this


# Configure selected source as clock or disable all inputs.  In the latter PLL1
# should also be disabled
def configure_clkin(lmk, input):
    # Start by disabling all unused inputs
    lmk.CLKIN0_EN = 0
    lmk.CLKIN1_EN = 0
    lmk.CLKIN2_EN = 0
    lmk.CLKIN3_EN = 0

    # Clock in selection is by register
    lmk.CLKINSEL1_MODE = 2      # Use register setting to select input

    if input is None:
        lmk.SW_REFINSEL = 0
    else:
        assert 0 <= input <= 3, 'Invalid input clock'
        lmk.SW_REFINSEL = 1 << input
        clkin = 'CLKIN%d' % input
        setattr(lmk, clkin + '_EN', 1)          # Enable selected clock
        setattr(lmk, clkin + '_SE_MODE', 0)     # All inputs are differential


# Configure OSCin.  Must be enabled unless using clock distribution directly
# from a CLKIN input
def configure_oscin(lmk, enable):
    lmk.OSCIN_PD_LDO = int(not enable)          # Power up OSCin
    lmk.OSCIN_OSCINSTAGE_EN = int(enable)       # Power up OSCin
    lmk.OSCIN_BUF_REF_EN = int(enable)          # Enable OSCin buffers to PLLs
    lmk.OSCIN_BUF_LOS_EN = int(enable)          #  and to LOS buffer
    lmk.PLL2_GLOBAL_BYP = int(not enable)       # Select PLL2 input source
    lmk.OSCIN_SE_MODE = 0                       # OSCin is differential


def configure_pll1(lmk, pll1, clkin):
    # A variety of flags need to be set or reset depending on whether PLL1 is
    # enabled or disabled
    enable = pll1 is not None
    lmk.PLL1EN = int(enable)                        # PLL1 enable
    lmk.CLKINBLK_EN_BUF_CLK_PLL = int(enable)       # Input buffer
    lmk.CLKINBLK_EN_BUF_BYP_PLL = int(not enable)   # Bypass buffer

    if pll1:
        assert clkin is not None, 'Must specify input clock to lock to'
        setattr(lmk, 'CLKIN%d_PLL1_RDIV' % clkin, pll1.r)
        lmk.PLL1_NDIV = pll1.n
        lmk.PLL1_PROP = pll1.prop
        lmk.PLL1_INTG = pll1.intg


def configure_pll2(lmk, pll2):
    enable = pll2 is not None
    lmk.PLL2EN = int(enable)
    lmk.PLL2_BYP_TOP = int(not enable)
    lmk.PLL2_BYP_BOT = int(not enable)
    lmk.PLL2_EN_BYP_BUF = int(not enable)
    lmk.PLL2_REF_CLK_EN = int(enable)
    lmk.PLL2_NDIV_CLKEN = int(enable)

    if pll2:
        # At most one of _DBL_EN_INV and _RDIV_DBL_EN or _RDIV_CLKEN should be
        # set
        lmk.PLL2_DBL_EN_INV = 0         # Don't support doubling the clock
        if pll2.double_r:
            lmk.PLL2_RDIV_DBL_EN = 1         # Doubles reference clock
            lmk.PLL2_RDIV_CLKEN = 0
        else:
            lmk.PLL2_RDIV_DBL_EN = 0
            lmk.PLL2_RDIV_CLKEN = 1
            lmk.PLL2_RDIV = pll2.r

        # Configure feedback

        lmk.PLL2_NBYPASS_DIV2_FB = 0    # Don't need extra divide by 2
        lmk.PLL2_NDIV = pll2.n
        assert 3 <= pll2.d <= 6, 'Invalid prescaler value'
        lmk.PLL2_PRESCALER = (pll2.d - 3) << 2

        # Configure filter parameters
        lmk.PLL2_PROP = pll2.prop
        lmk.PLL2_CPROP = pll2.cprop
        lmk.PLL2_INTG = pll2.intg


def configure_clock_output(lmk, n, out):
    # Available output drive options
    modes = {
        'off'       : 0,
        'HSDS8mA'   : 0x18,
        'HSDS6mA'   : 0x14,
        'HSDS4mA'   : 0x10,
        'HCSL'      : 0x3F,     # SNAS663B 9.3.2.1 (HCSL 16mA open load)
        'HCSL8mA'   : 0x3B,
        'HCSL16mA'  : 0x3F,
    }

    assert 0 <= n < 8, 'Invalid output selection'
    out0 = 'OUTCH%d' % (2*n)
    out1 = 'OUTCH%d' % (2*n + 1)
    group = 'OUTCH%d%d' % (2*n, 2*n + 1)
    ch = 'CH%d_%d' % (2*n, 2*n + 1)
    if out:
        setattr(lmk, group + '_DIV_CLKEN', 1)   # Enable this output group
        setattr(lmk, group + '_DIV', out.div)       # Configure selected divider
        setattr(lmk, out0 + '_DRIV_MODE', modes[out.drv0])
        setattr(lmk, out1 + '_DRIV_MODE', modes[out.drv1])
        setattr(lmk, 'DIV_DCC_EN_' + ch, 1)     # Enable duty cycle correction
        setattr(lmk, 'DRIV_%d_SLEW' % (2*n), out.slew)
        setattr(lmk, 'DRIV_%d_SLEW' % (2*n + 1), out.slew)
        setattr(lmk, 'SYSREF_BYP_DYNDIGDLY_GATING_' + ch, 1)
        setattr(lmk, 'SYSREF_BYP_ANALOGDLY_GATING_' + ch, 1)
    else:
        # Disable this group and power down the unused outputs
        setattr(lmk, group + '_DIV_CLKEN', 0)
        setattr(lmk, out0 + '_DRIV_MODE', 0)
        setattr(lmk, out1 + '_DRIV_MODE', 0)


def configure_sync(lmk, ports):
    enables = 8 * [False]
    for port in ports:
        enables[port] = True
    all_disabled = 4 * [False]

    lmk.PLL2_EN_BUF_SYNC_TOP = int(enables[4:] != all_disabled)
    lmk.PLL2_EN_BUF_SYNC_BOTTOM = int(enables[:4] != all_disabled)

    lmk.GLOBAL_SYNC = 0
    lmk.EN_SYNC_PIN_FUNC = 0        # Disable SYNC from input pin

    for n, enable in enumerate(enables):
        ch = 'CH%d_%d' % (2*n, 2*n + 1)
        setattr(lmk, 'SYNC_EN_' + ch, enable)



def configure_lmk(lmk, config):
    configure_lmk_common(lmk)

    # bypassed and disabled.
    configure_clkin(lmk, config.clkin)
    configure_oscin(lmk, config.oscin)
    configure_pll1(lmk, config.pll1, config.clkin)
    configure_pll2(lmk, config.pll2)

    for n, out in enumerate(config.outputs):
        configure_clock_output(lmk, n, out)

    configure_sync(lmk, config.sync_ports)


@export
def setup_lmk(_lmk, config : Config):
    # Need to wait for the device to settle after reset as recommended in a
    # forum posting here: https://e2e.ti.com/support/clock-timing-group/
    # clock-and-timing/f/clock-timing-forum/835700/lmk04616-resetn-recovery-time
    if _lmk:
        _lmk.reset()
    time.sleep(0.15)

    # Create the wrapper register interface
    lmk = LMK04616(_lmk)

    configure_lmk(lmk, config)
    lmk.write_config()

    if config.sync_ports and _lmk:
        lmk.GLOBAL_SYNC = 1
        time.sleep(0.01)
        lmk.GLOBAL_SYNC = 0

    return lmk
