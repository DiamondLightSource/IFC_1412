# Defines mapping to test-gddr6 registers

import os

from ifc_lib import fpga_lib
from fpga_lib.driver import driver

here = os.path.dirname(__file__)
register_defines = os.path.join(here, '../vhd/register_defines.in')
gddr6_defines = os.path.join(here, '../../gddr6/vhd/gddr6_register_defines.in')

REGS_RANGE = slice(0, 1024, None)
SG_RANGE = slice(1024, 2408, None)


def open(addr = 0):
    raw_regs = driver.RawRegisters('ifc_1412-gddr6', addr)
    sys_regs = driver.Registers(raw_regs, register_defines, range = REGS_RANGE)
    sg_regs = driver.Registers(raw_regs, gddr6_defines, range = SG_RANGE)
    return (sys_regs.SYS, sg_regs.GDDR6)


# __all__ = ['regs', 'sg']
