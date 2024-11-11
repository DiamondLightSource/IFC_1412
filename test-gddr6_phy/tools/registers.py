# Defines mapping to test-gddr6 registers

import os

from ifc_lib import fpga_lib
from fpga_lib.driver import driver

here = os.path.dirname(__file__)
register_defines = os.path.join(here, '../vhd/register_defines.in')
gddr6_defines = os.path.join(here, '../../gddr6/vhd/gddr6_register_defines.in')


def open(addr = 0):
    raw_regs = driver.RawRegisters('ifc_1412-gddr6', addr)
    regs = driver.Registers(raw_regs, gddr6_defines, register_defines)
    return (regs.SYS, regs.SYS.GDDR6)

__all__ = ['open']
