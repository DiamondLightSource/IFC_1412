# Given LMK register return bindings

import time

from fpga_lib import devices


# read/write/reset bindings for LMK
class RawLMK:
    # Call with select = 'sys' for SYS LMK, 'acq' for ACQ LMK
    def __init__(self, lmk, select):
        self.__lmk = lmk
        self.__select = { 'acq' : 1, 'sys' : 0 }[select]

    def write(self, reg, value):
        self.__lmk._write_fields_wo(SELECT = self.__select)
        self.__lmk._write_fields_wo(
            SELECT = self.__select,
            ADDRESS = reg, R_WN = 0, DATA = value, ENABLE = 1)

    def read(self, reg):
        self.__lmk._write_fields_wo(SELECT = self.__select)
        self.__lmk._write_fields_wo(
            SELECT = self.__select,
            ADDRESS = reg, R_WN = 1, ENABLE = 1)
        return self.__lmk.DATA

    def reset(self, duration = 0.01):
        self.__lmk._write_fields_wo(SELECT = self.__select)
        self.__lmk._write_fields_wo(SELECT = self.__select, RESET = 1)
        time.sleep(duration)
        self.__lmk._write_fields_wo(SELECT = self.__select, RESET = 0)


class LMK04616(devices.LMK04616):
    def __init__(self, lmk_reg, select):
        self.__lmk = RawLMK(lmk_reg, select)
        super().__init__(self.__lmk)
        self._reset = self.__lmk.reset


__all__ = ['RawLMK', 'LMK04616']
