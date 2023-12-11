# Defines mapping to test-gddr6 registers

import os

from fpga_lib.driver import driver

here = os.path.dirname(__file__)
register_defines = os.path.join(here, '../vhd/register_defines.in')
gddr6_defines = os.path.join(here, '../../gddr6/vhd/gddr6_register_defines.in')

raw_regs = driver.RawRegisters('ifc_1412-gddr6', 0)

regs = driver.Registers(raw_regs, gddr6_defines, register_defines)
sg = regs.SYS.GDDR6


def write_lmk(reg, value):
    regs.SYS.LMK04616._write_fields_wo(
        ADDRESS = reg, R_WN = 0, SELECT = 0, DATA = value)

def read_lmk(reg):
    regs.SYS.LMK04616._write_fields_wo(ADDRESS = reg, R_WN = 1, SELECT = 0)
    return regs.SYS.LMK04616.DATA



def is_bitslip_address(address):
    return (address & 0xC0) == 0x80 or (address & 0xF0) == 0xC0

def step_delay(address, amount):
    assert not is_bitslip_address(address)
    if amount == 0:
        return
    elif amount < 0:
        up_down_n = 0
        amount = - amount
    else:
        up_down_n = 1
    sg.DELAY._write_fields_wo(
        ADDRESS = address, DELAY = amount - 1, UP_DOWN_N = up_down_n,
        ENABLE_WRITE = 1)

def set_delay(address, target):
    if is_bitslip_address(address):
        sg.DELAY._write_fields_wo(
            ADDRESS = address, DELAY = target, ENABLE_WRITE = 1)
    else:
        step_delay(address, target - read_delay(address))

def read_delay(address):
    sg.DELAY._write_fields_wo(ADDRESS = address, ENABLE_WRITE = 0)
    return sg.DELAY.DELAY

def byteslip(address):
    sg.DELAY._write_fields_wo(ADDRESS = address, BYTESLIP = 1, ENABLE_WRITE = 1)


# __all__ = ['sg', 'step_delay', 'set_delay', 'read_delay', 'byteslip']
