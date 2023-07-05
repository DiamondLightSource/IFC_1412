# Module for configuring system LMK

import time

from fpga_lib.devices import LMK04616


def set_output_pair(lmk, n, div, drv0 = 0x10, drv1 = 0x10, slew = 1):
    assert n % 2 == 0 and 0 <= n < 15, 'Invalid output selection'
    m = n + 1
    out0 = 'OUTCH%d' % n
    out1 = 'OUTCH%d' % m
    group = 'OUTCH%d%d' % (n, m)
    ch = 'CH%d_%d' % (n, m)
    setattr(lmk, group + '_DIV_CLKEN', 1)   # Enable this output group
    setattr(lmk, group + '_DIV', div)       # Configure selected divider
    setattr(lmk, out0 + '_DRIV_MODE', drv0) # Selected drive mode for each
    setattr(lmk, out1 + '_DRIV_MODE', drv1) #  output
    setattr(lmk, 'DIV_DCC_EN_' + ch, 1)     # Enable duty cycle correction
    setattr(lmk, 'DRIV_%d_SLEW' % n, slew)
    setattr(lmk, 'DRIV_%d_SLEW' % m, slew)

#     setattr(lmk, 'SYSREF_BYP_DYNDIGDLY_GATING_' + ch, 1)
#     setattr(lmk, 'SYSREF_BYP_ANALOGDLY_GATING_' + ch, 1)


# This LMK drives the following outputs:
#
#   CLKOUT0  @ 125 MHz  => RTM GTP 13-12
#   CLKOUT1  @ 125 MHz  => MGT 126 for AMC 1-0 and RTM GTP 13-12
#   CLKOUT2  @ 125 MHz  => MGT 227 for FMC1
#   CLKOUT3  @ 125 MHz  => MGT 229 for FMC1
#   CLKOUT4  @ 125 MHz  => MGT 127 for FMC2
#   CLKOUT5  @ 125 MHz  => MGT 230 for FMC2
#   CLKOUT6  @ 125 MHz  => MGT 232 for RTM GTP 3-0
#   CLKOUT7  @ 125 MHz  => RTM GTP 3-0
#   CLKOUT8  @ 1 GHz    => WCK_A to GDDR
#   CLKOUT9  @ 1 GHz    => WCK_A to bank 24 QBC
#   CLKOUT10 @ 1 GHz    => WCK_B to GDDR
#   CLKOUT11 @ 1 GHz    => WCK_B to bank 25 QBC
#   CLKOUT12 @ 250 MHz  => CK to GDDR
#   CLKOUT13            => (unused)
#   CLKOUT14 @ 250 MHz  => CK to bank 24 GC
#   CLKOUT15            => (unused)
#
# If we can use 100 MHz as the MGT reference clock it may be worth considering
# increasing the GDDR WCK frequency to 1.2 GHz (and CK to 300 MHz).
def configure_sys_lmk(lmk, use_fclk = True):
    # First ensure we are in SPI 3-wire mode
    lmk.SPI_EN_THREE_WIRE_IF = 1    # Use SDIO for input and output

    # Put PLL2 lock status on STATUS0
    lmk.STATUS0_MUX_SEL = 4
    lmk.STATUS0_INT_MUX = 2         # PLL2 lock detect on STATUS0
    lmk.STATUS0_OUTPUT_HIZ = 0      # Ensure output is driven
    lmk.PLL2_LD_WNDW_SIZE = 0       # Needs to be cleared from reset state
    lmk.PLL2_LD_WNDW_SIZE_INITIAL = 0   # as does this

    # Run with PLL1 bypassed and disabled
    lmk.PLL1EN = 0
    lmk.PLL2EN = 1

    # There are two possible clock input selections available, either the FCLK
    # or a crystal oscillator, both running at 100 MHz.
    if use_fclk:
        # FCLK comes in on CLKIN0
        lmk.CLKIN0_EN = 1           # Use CLKIN0
        lmk.CLKIN0_SE_MODE = 0      # Differential input clock
        lmk.CLKINSEL1_MODE = 2      # Use register setting to select input
        lmk.SW_REFINSEL = 1         # Select CLKIN0
        lmk.OSCIN_PD_LDO = 1        # Power down OSCin, not wanted
        lmk.OSCIN_OSCINSTAGE_EN = 0 # Power down
        lmk.OSCIN_BUF_REF_EN = 0
        lmk.PLL2_GLOBAL_BYP = 1     # Input from CLKIN0
    else:
        # Crystal input on OSCin
        lmk.CLKIN0_EN = 0           # Disable CLINK0
        lmk.OSCIN_PD_LDO = 0        # Power up OSCin
        lmk.OSCIN_SE_MODE = 0       # Wired for differential input
        lmk.OSCIN_OSCINSTAGE_EN = 1 # Power up OSCin
        lmk.OSCIN_BUF_REF_EN = 1
        lmk.PLL2_GLOBAL_BYP = 0     # Input from OSCin

    # Disable unused inputs
    lmk.CLKIN1_EN = 0
    lmk.CLKIN2_EN = 0
    lmk.CLKIN3_EN = 0

    lmk.CLKINBLK_EN_BUF_CLK_PLL = 0 # Disable PLL1 input
    lmk.CLKINBLK_EN_BUF_BYP_PLL = 1 # Bypass PLL1, enable PLL2 input

    lmk.OSCOUT_DRV_MODE = 0         # Power down OSCOUT, not connected
    lmk.OSCIN_BUF_TO_OSCOUT_EN = 0  # Don't need this buffer

#     # SYNC setup
#     lmk.PLL2_EN_BUF_SYNC_TOP = 1    # Use SYNC on outputs 8 to 15
#     lmk.PLL2_EN_BUF_SYNC_BOTTOM = 0 #  but not 0 to 7

    # Configuration of PLL2
    lmk.PLL2_DBL_EN_INV = 1         # Doubles reference clock
    # Reference clock is 200 MHz, VCO runs at 6000 MHz = 30 * 200, we use three
    # stages of divider for feedback 30 = 3 * 2 * 5
    lmk.PLL2_NDIV = 5
    lmk.PLL2_NBYPASS_DIV2_FB = 1    # Extra divide by 2
    lmk.PLL2_PRESCALER = 0          # Set prescaler to divide by 3

    # PLL2 filter parameters from IOxOS
    lmk.PLL2_PROP = 0x25            # PLL2 charge pump gain

    # Configure all outputs as requred

    # RTM GTP 13-12 CLK IN and MGT 126 for AMC 1-0.
    # Frequency must be 125 MHz
    set_output_pair(lmk,  0,  div = 16)
    # MGT 227 and 229 for FMC 1
    set_output_pair(lmk,  2,  div = 16)
    # MGT 127 and 230 for FMC2
    set_output_pair(lmk,  4,  div = 16)
    # MGT 232 and RTM GTP 3-0
    set_output_pair(lmk,  6,  div = 16)

    # WCK_A to SGRAM and QBC bank 24
    set_output_pair(lmk,  8,
        div = 4, drv0 = 0x18, drv1 = 0x18, slew = 0)
    # WCK_B to SGRAM and QBC bank 25
    set_output_pair(lmk, 10,
        div = 4, drv0 = 0x18, drv1 = 0x18, slew = 0)
    # CK to SGRAM (13 is unused)
    set_output_pair(lmk, 12,
        div = 8, drv0 = 0x18, drv1 = 0, slew = 0)
    # CK to GC bank 24 (15 unused)
    set_output_pair(lmk, 14,
        div = 8, drv0 = 0x18, drv1 = 0, slew = 0)


def set_sync_enable(lmk, n, enable):
    m = n + 1
    ch = 'CH%d_%d' % (n, m)
    setattr(lmk, 'SYNC_EN_' + ch, enable)

def setup_sync(lmk, enable_sync_pin):
    lmk.PLL2_EN_BUF_SYNC_TOP = 1    # Use SYNC on outputs 8 to 15
    lmk.PLL2_EN_BUF_SYNC_BOTTOM = 0 #  but not 0 to 7

    lmk.GLOBAL_SYNC = 0
    if enable_sync_pin:
        lmk.EN_SYNC_PIN_FUNC = 1        # Enable SYNC from input pin
        lmk.SYNC_PIN_FUNC = 0           # Use pin to enable SYNC
        lmk.SYNC_ENB_INSTAGE = 0        # Must be 0 to enable SYNC input
        lmk.SYNC_OUTPUT_HIZ = 1         # Enable SYNC as input
        lmk.SYNC_EN_ML_INSTAGE = 0      # Set this to enable extended SYNC
    else:
        lmk.EN_SYNC_PIN_FUNC = 0        # Disable SYNC from input pin

    set_sync_enable(lmk, 0,  0)
    set_sync_enable(lmk, 2,  0)
    set_sync_enable(lmk, 4,  0)
    set_sync_enable(lmk, 6,  0)
    set_sync_enable(lmk, 8,  1)
    set_sync_enable(lmk, 10, 1)
    set_sync_enable(lmk, 12, 0)     # Only goes to GDDR, must leave alone
    set_sync_enable(lmk, 14, 1)     # Want to disable in real application


def setup_sys_lmk(top, use_fclk = True, enable_sync_pin = True):
    def write_lmk(reg, value):
        top.LMK04616._write_fields_wo(
            ADDRESS = reg, R_WN = 0, SELECT = 0, DATA = value)

    def read_lmk(reg):
        top.LMK04616._write_fields_wo(ADDRESS = reg, R_WN = 1, SELECT = 0)
        return top.LMK04616.DATA

    # First reset the LMK
    # Not quite sure how long we have to wait
    top.CONFIG._write_fields_rw(LMK_SELECT = 0, LMK_RESET = 1)
    time.sleep(0.01)
    top.CONFIG._write_fields_rw(LMK_SELECT = 0, LMK_RESET = 0)
    # Need to wait for the device to settle after reset as recommended in a
    # forum posting here: https://e2e.ti.com/support/clock-timing-group/
    # clock-and-timing/f/clock-timing-forum/835700/lmk04616-resetn-recovery-time
    time.sleep(0.15)

    # Create the wrapper register, configure and write
    lmk = LMK04616(writer = write_lmk, reader = read_lmk)
    configure_sys_lmk(lmk, use_fclk)
    setup_sync(lmk, enable_sync_pin)
    lmk.write_config()

    return lmk
