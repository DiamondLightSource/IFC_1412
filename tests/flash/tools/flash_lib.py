# Support for flash operations

import struct
import numpy

from ifc_lib import defs_path
from fpga_lib.driver import driver


class Registers(driver.RawRegisters):
    NAME = 'ifc_1412-flash'

    def __init__(self, address = 0):
        super().__init__(self.NAME, address)

        register_defines = defs_path.register_defines(__file__)
        self.make_registers('TOP', None, register_defines)

def open(address = 0):
    regs = Registers(address)
    return regs.TOP.FLASH


def delay_type(arg):
    result = int(arg)
    if not 0 <= result < 8:
        raise ValueError('Invalid value for read delay')
    return result

def add_common_args(parser):
    parser.add_argument(
        '-a', dest = 'addr', default = 0,
        help = 'Set physical address of card.  If not specified then card 0')
    parser.add_argument(
        '-s', dest = 'select', default = 'user',
        choices = SelectOptions.keys(),
        help = 'Select which FLASH memory to access')
    parser.add_argument(
        '-c', dest = 'clock', default = '63M',
        choices = SpeedOptions.keys(),
        help = 'Select SPI clock speed')
    parser.add_argument(
        '-r', dest = 'read_delay', default = 3, type = delay_type,
        help = 'Read delay')


def open_with_args(args):
    flash = open(args.addr)
    return Exchange(flash, args.select, args.clock, args.read_delay)


# Options for select
USER = 1
FPGA1 = 2
FPGA2 = 3

# Options for clock speed
SPEED_125M = 0
SPEED_63M = 1
SPEED_42M = 2
SPEED_31M = 3


SelectOptions = { 'user' : 1, 'fpga1' : 2, 'fpga2' : 3 }
SpeedOptions = { '125M' : 0, '63M' : 1, '42M' : 2, '31M' : 3 }


class Exchange:
    def __init__(self, flash, select, clock_speed, read_delay):
        self.flash = flash
        self.select = SelectOptions[select]
        self.clock_speed = SpeedOptions[clock_speed]
        self.read_delay = read_delay

    def exchange(self, command, write, read, long_cs_high = False):
        # Upload command and write string.  Concatenate the command and write
        # string and pad out to a multiple of four bytes so the data can be
        # written as 32-bit integers
        command = bytearray([command])
        write = bytearray(write)
        padding = (3 - (len(write) % 4)) * b'\xff'
        command = numpy.frombuffer(
            command + write + padding, dtype = numpy.uint8)
        for word in command.view(numpy.uint32):
            self.flash.DATA._value = word

        # Now perform the requested transaction
        self.flash.COMMAND._write_fields_wo(
            LENGTH = len(write) + read,
            READ_OFFSET = len(write),
            SELECT = self.select,
            READ_DELAY = self.read_delay,
            CLOCK_SPEED = self.clock_speed,
            LONG_CS_HIGH = long_cs_high)

        # Finally read back the requested bytes as words and unpack
        word_count = (read + 3) // 4
        result = numpy.empty(word_count, dtype = numpy.uint32)
        for i in range(word_count):
            result[i] = self.flash.DATA._value
        return result.view(numpy.uint8)[:read]

    def REMS(self):
        '''Read Identification, should return 01 19'''
        return self.exchange(0x90, [0, 0, 0], 2)

    def WREN(self):
        '''Set Write Enable Latch to enable modification of memory.'''
        self.exchange(0x06, b'', 0)

    def WRDI(self):
        '''Clear Write Enable Latch'''
        self.exchange(0x04, b'', 0)

    def WVDLR(self, pattern):
        '''Writes the volatile data learning pattern.  Must be preceded by WREN
        to enable writing.'''
        self.exchange(0x4A, [pattern], 0)

    def DLPRD(self, count = 1):
        '''Return the data learning pattern written by WVDLR'''
        return self.exchange(0x41, b'', count)[0]

    def RDSR1(self):
        '''Reads Status Register 1'''
        return self.exchange(0x05, b'', 1)[0]

    def RDSR2(self):
        '''Reads Status Register 2'''
        return self.exchange(0x07, b'', 1)[0]

    def RDCR(self):
        '''Reads Configuration Register'''
        return self.exchange(0x07, b'', 1)[0]

    def FAST_READ(self, address, count):
        '''Reads block of memory'''
        result = self.exchange(0x0C, struct.pack('>IB', address, 255), count)
        return bytearray(result)

    def PP(self, address, data):
        '''Programs one page of data up to 512 bytes long'''
        assert 0 < len(data) <= 512, 'Invalid data block length'
        assert (address & 0x1FF) + len(data) <= 512, 'Misaligned address'
        address = struct.pack('>I', address)
        self.exchange(0x12, address + data, 0)

    def SE(self, address):
        '''Erases the selected 256KB sector.'''
        assert address & 0x3FFFF == 0, 'Misaligned sector address'
        self.exchange(0xDC, struct.pack('>I', address), 0)
