# Support for flash operations

import sys
import struct
import numpy

from ifc_lib import defs_path
from fpga_lib.driver import driver


SelectOptions = { 'user' : 1, 'fpga1' : 2, 'fpga2' : 3 }
SpeedOptions = { '125M' : 0, '63M' : 1, '42M' : 2, '31M' : 3 }

BASE_DELAY = 3

SECTOR_SIZE = 0x40000
PAGE_SIZE = 512



def fail(message):
    print(message, file = sys.stderr)
    sys.exit(1)


class Registers(driver.RawRegisters):
    NAME = 'ifc_1412-flash'

    def __init__(self, address = 0):
        super().__init__(self.NAME, address)

        register_defines = defs_path.register_defines(__file__)
        mailbox_defines = defs_path.module_defines('mailbox')
        self.make_registers('TOP', None, mailbox_defines, register_defines)

        readback = self.TOP.FLASH.COMMAND._value
        if readback != 0:
            fail('Command readback = %08X, need to rescan PCI bus' % readback)

def open(address = 0):
    regs = Registers(address)
    return regs.TOP


def delay_type(arg):
    result = int(arg)
    if not 0 <= result < 8:
        raise ValueError('Invalid value for read delay')
    return result

def add_common_args(parser, select = True):
    parser.add_argument(
        '-a', dest = 'addr', default = 0,
        help = 'Set physical address of card.  If not specified then card 0')
    if select:
        parser.add_argument(
            '-s', dest = 'select', default = 'user',
            choices = SelectOptions.keys(),
            help = 'Select which FLASH memory to access')
    parser.add_argument(
        '-c', dest = 'clock', default = '63M',
        choices = SpeedOptions.keys(),
        help = 'Select SPI clock speed')
    parser.add_argument(
        '-r', dest = 'read_delay', default = BASE_DELAY, type = delay_type,
        help = 'Read delay')


def open_with_args(args):
    top = open(args.addr)
    return Exchange(top.FLASH, args.select, args.clock, args.read_delay)



class Progress:
    SYMBOL = '|/-\\'

    def __init__(self, size):
        self.size = size
        self.state = 0

    def report(self, address, end = '\r'):
        progress = 100 * address / self.size
        symbol = self.SYMBOL[self.state]
        self.state = (self.state + 1) % len(self.SYMBOL)
        print('{} {:4.1f}% {}'.format(symbol, progress, address), end = end)

    def done(self):
        self.report(self.size, '\n')


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

    def OTPR(self, address, count):
        '''Read from one time programmable array'''
        address = struct.pack('>BHB', 0, address, 255)
        return self.exchange(0x4B, address, count)

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

    def ABRD(self):
        '''Reads autoboot register'''
        return self.exchange(0x14, b'', 4).view('uint32')[0]

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
