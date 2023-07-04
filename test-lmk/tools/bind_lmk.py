# Quick and dirty binding to SYS LMK

import os

from fpga_lib.driver import driver
from fpga_lib.devices import LMK04616


here = os.path.dirname(__file__)
register_defines = os.path.join(here, '../vhd', 'register_defines.in')
raw_regs = driver.RawRegisters('ifc_1412-regs', 1)
regs = driver.Registers(raw_regs, register_defines)
top = regs.TOP

def write_lmk(reg, value):
    top.LMK04616._write_fields_wo(
        ADDRESS = reg, R_WN = 0, SELECT = 0, DATA = value)

def read_lmk(reg):
    top.LMK04616._write_fields_wo(ADDRESS = reg, R_WN = 1, SELECT = 0)
    return top.LMK04616.DATA

lmk = LMK04616(writer = write_lmk, reader = read_lmk)
lmk.enable_write()
