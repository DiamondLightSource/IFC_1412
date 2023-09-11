# Defines mapping to test-gddr6 registers

import os

from fpga_lib.driver import driver

driver.VERBOSE = True

here = os.path.dirname(__file__)
register_defines = os.path.join(here, '../vhd/register_defines.in')
gddr6_defines = os.path.join(here, '../../gddr6/vhd/gddr6_register_defines.in')

raw_regs = driver.RawRegisters('ifc_1412-gddr6', 1)

regs = driver.Registers(raw_regs, gddr6_defines, register_defines)
