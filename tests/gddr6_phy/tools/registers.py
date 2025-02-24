# Defines mapping to test-gddr6 registers

from ifc_lib import defs_path
from fpga_lib.driver import driver


class Registers(driver.RawRegisters):
    NAME = 'ifc_1412-gddr6'

    def __init__(self, address = 0):
        super().__init__(self.NAME, address)

        register_defines = defs_path.register_defines(__file__)
        gddr6_defines = defs_path.gddr6_register_defines()

        self.make_registers('SYS', None, gddr6_defines, register_defines)

def open(addr = 0):
    regs = Registers(addr)
    return (regs.SYS, regs.SYS.GDDR6)

__all__ = ['open']
