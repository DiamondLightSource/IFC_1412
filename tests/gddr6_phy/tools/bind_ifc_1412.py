# Defines mapping to test-gddr6 registers

import os
import numpy

from ifc_lib import defs_path
from fpga_lib.driver import driver

class Registers(driver.RawRegisters):
    NAME = 'ifc_1412-gddr6'

    def __init__(self, address = 0):
        super().__init__(self.NAME, address)

        register_defines = defs_path.register_defines(__file__)
        gddr6_defines = defs_path.module_defines('gddr6')
        lmk04616_defines = defs_path.module_defines('lmk04616')
        self.make_registers('SYS', None,
            gddr6_defines, lmk04616_defines, register_defines)

def open(addr = 0):
    regs = Registers(addr)
    return (regs.SYS, regs.SYS.GDDR6)

__all__ = ['open']
