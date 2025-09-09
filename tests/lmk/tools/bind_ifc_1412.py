# Bind to IFC_1412 firmware for scripting support
#
# Must provide open() method returning registers for TOP and GDDR6 (if present)

from ifc_lib import defs_path
from fpga_lib.driver import driver

class Registers(driver.RawRegisters):
    NAME = 'ifc_1412-lmk'

    def __init__(self, address = 0):
        super().__init__(self.NAME, address)

        register_defines = defs_path.register_defines(__file__)
        lmk04616_defines = defs_path.module_defines('lmk04616')
        self.make_registers('TOP', None, lmk04616_defines, register_defines)

def open(addr = 0):
    regs = Registers(addr)
    return (regs.TOP, None)

__all__ = ['open']
