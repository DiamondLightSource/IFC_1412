# Quick and dirty binding to SYS LMK

import os
import time

from fpga_lib.driver import driver
from fpga_lib.devices import LMK04616


# read/write/reset bindings for LMK
class LMK:
    # Call with select = 'sys' for SYS LMK, 'acq' for ACQ LMK
    def __init__(self, top, select):
        self.__top = top
        self.__select = { 'acq' : 1, 'sys' : 0 }[select]

    def write(self, reg, value):
        self.__top.LMK04616._write_fields_wo(
            ADDRESS = reg, R_WN = 0, SELECT = self.__select, DATA = value)

    def read(self, reg):
        self.__top.LMK04616._write_fields_wo(
            ADDRESS = reg, R_WN = 1, SELECT = self.__select)
        return self.__top.LMK04616.DATA

    def reset(self, duration = 0.01):
        self.__top.CONFIG._write_fields_rw(LMK_SELECT = self.__select)
        self.__top.CONFIG._write_fields_rw(
            LMK_SELECT = self.__select, LMK_RESET = 1)
        time.sleep(duration)
        self.__top.CONFIG._write_fields_rw(
            LMK_SELECT = self.__select, LMK_RESET = 0)


class DummyLMK:
    def write(self, reg, value):
        print('PLL[%03X] <= %02x' % (reg, value))

    def read(self, reg):
#         print('read[%03X]' % reg)
        return 0

    def reset(self, duration = 0.01):
#         print('reset')
        pass


# Opens test-lmk device and returns binding to registers
def open(addr = 0):
    here = os.path.dirname(__file__)
    register_defines = os.path.join(here, '../vhd', 'register_defines.in')
    raw_regs = driver.RawRegisters('ifc_1412-lmk', addr)
    regs = driver.Registers(raw_regs, register_defines)
    return regs.TOP


# Binds LMK instance to given top, returns read/write access
def bind(top, select):
    lmk = LMK(top, select)
    lmk = LMK04616(writer = lmk.write, reader = lmk.read)
    lmk.enable_write()
    return lmk

__all__ = ['open', 'bind', 'LMK']
