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


TARGET_IDELAY = 0
TARGET_ODELAY = 1
TARGET_OBITSLIP = 3


def step_delay(target, address, amount):
    if amount == 0:
        return
    elif amount < 0:
        up_down_n = 0
        amount = - amount
    else:
        up_down_n = 1
    sg.DELAY._write_fields_wo(
        ADDRESS = address, TARGET = target,
        DELAY = amount - 1, UP_DOWN_N = up_down_n,
        ENABLE_WRITE = 1)


def read_delay(target, address):
    sg.DELAY._write_fields_wo(
        ADDRESS = address, TARGET = target, ENABLE_WRITE = 0)
    return sg.DELAY.DELAY


def read_idelay(address):
    return read_delay(TARGET_IDELAY, address)

def read_odelay(address):
    return read_delay(TARGET_ODELAY, address)

def read_obitslip(address):
    return read_delay(TARGET_OBITSLIP, address)

def set_idelay(address, delay):
    step_delay(TARGET_IDELAY, address, delay - read_idelay(address))

def set_odelay(address, delay):
    step_delay(TARGET_ODELAY, address, delay - read_odelay(address))

def set_obitslip(address, delay):
    sg.DELAY._write_fields_wo(
        ADDRESS = address, TARGET = TARGET_OBITSLIP,
        DELAY = delay, ENABLE_WRITE = 1)

def last_delay():
    return sg.DELAY.DELAY


# __all__ = ['sg', 'step_delay', 'set_delay', 'read_delay', 'byteslip']
