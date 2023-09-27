# Defines mapping to test-gddr6 registers

import os

from fpga_lib.driver import driver

here = os.path.dirname(__file__)
register_defines = os.path.join(here, '../vhd/register_defines.in')
gddr6_defines = os.path.join(here, '../../gddr6/vhd/gddr6_register_defines.in')

raw_regs = driver.RawRegisters('ifc_1412-gddr6', 1)

regs = driver.Registers(raw_regs, gddr6_defines, register_defines)
sg = regs.SYS.GDDR6


def read_riu(nibble, reg):
    riu = sg.RIU
    address = (nibble << 6) | (reg & 0x3F)

    riu._write_fields_wo(ADDRESS = address, WRITE = 0, VTC = 1)
    result = riu._get_fields()
    assert not result.TIMEOUT
    return result.DATA

def write_riu(nibble, reg, value):
    riu = sg.RIU
    address = (nibble << 6) | (reg & 0x3F)
    riu._write_fields_wo(DATA = value, ADDRESS = address, WRITE = 1, VTC = 1)
    result = riu._get_fields()
    assert not result.TIMEOUT

def slew_rx_delay(nibble, pin, target):
    # Only applies to RX pins
    pin_address = pin + 6
    riu_address = pin + 0x12
    current = read_riu(nibble, riu_address)
    while target > current:
        write_riu(nibble, pin_address, min(current + 7, target))
        current = read_riu(nibble, riu_address)
    while target < current:
        write_riu(nibble, pin_address, max(current - 7, target))
        current = read_riu(nibble, riu_address)

def slew_tx_delay(nibble, pin, target):
    # Only applies to RX pins
    pin_address = pin + 0
    riu_address = pin + 0x0B
    current = read_riu(nibble, riu_address)
    while target > current:
        write_riu(nibble, pin_address, min(current + 7, target))
        current = read_riu(nibble, riu_address)
    while target < current:
        write_riu(nibble, pin_address, max(current - 7, target))
        current = read_riu(nibble, riu_address)



__all__ = ['sg', 'read_riu', 'write_riu', 'slew_rx_delay', 'slew_tx_delay']