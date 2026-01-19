# Generic support for reading and writing the MMC mailbox

import struct


__all__ = ['read_mailbox', 'write_mailbox', 'read_slot', 'read_message']

class MailboxError(Exception):
    pass

def fail(message):
    raise MailboxError(message)



def get_array_entry(array, ix, default):
    try:
        return array[ix]
    except IndexError:
        return default


def read_array(mailbox, message, count):
    result = []
    for n in range(count):
        mailbox._write_fields_wo(
            MSG_ADDR = message, BYTE_ADDR = n, WRITE = 0)
        result.append(mailbox.DATA)
    return result


def read_mailbox(mailbox, address):
    '''Reads raw content of the specified mailbox message'''
    result = ' '.join([
        f'{data:02X}'
        for data in read_array(mailbox, address, 32)])
    return result


def write_mailbox(mailbox, message, values):
    '''Writes specified mailbox message'''
    for n, value in enumerate(values):
        mailbox._write_fields_wo(
            MSG_ADDR = message, BYTE_ADDR = n, DATA = value, WRITE = 1)


# Common code for interpreting mailbox messages
class Message:
    # Must define the following in a subclass:
    __fields__ = []
    __message_id__ = 0
    __struct__ = ''
    __length__ = 0

    def __init__(self, *values):
        for field, value in zip(self.__fields__, values):
            setattr(self, field, value)

    @classmethod
    def read(cls, mailbox):
        data = bytes(read_array(mailbox, cls.__message_id__, cls.__length__))
        if not any(data):
            fail('Nothing written to mailbox {cls.__message_id__}')
        checksum = (cls.__message_id__ + sum(data)) % 256
        if checksum != 0:
            show_data = ' '.join(f'{x:02X}' for x in data)
            fail(f'Invalid checksum: {checksum:02X} ({show_data})')

        return cls(*struct.unpack(cls.__struct__, data[:-1]))

    def __repr__(self):
        values = ', '.join(
            f'{name} = {getattr(self, name)}' for name in self.__fields__)
        return f'{self.__class__.__name__}: {values}'


class MMC_Message(Message):
    __fields__ = ['ver', 'product', 'version', 'serial', 'slot']
    __message_id__ = 0
    # Decode mailbox according to following structure (all number big endian):
    #   0       Message version
    #   2:1     Product number (1412)
    #   3       Product version
    #   7:4     Product serial number
    #   8       AMC slot
    __struct__ = '>BHBLB'
    __length__ = 10

    def format(self):
        return \
            f'Product: {self.product} v{self.version} serial ' \
            f'{self.serial} in slot {self.slot}'

class RTM_Message(Message):
    __fields__ = ['ver', 'state', 'product', 'version', 'serial']
    __message_id__ = 1
    # Decode mailbox according to following structure (all number big endian):
    #   0       Message version
    #   2:1     Product number (1412)
    #   3       Product version
    #   7:4     Product serial number
    #   8       AMC slot
    __struct__ = '>BBHBL'
    __length__ = 10

    def format(self):
        state = get_array_entry(
            ['absent', 'present', 'powered'], self.state, 'unknown');
        return \
            f'Ver: {self.ver} RTM {state} ' \
            f'Product: {self.product} v{self.version} serial {self.serial}'

class PayloadMessage(Message):
    __fields__ = [
        'ver',
        'fpga_image',
        'jtag_master',
        'jtag_rtm',
        'acq_clk_src',
        'acq_clk_vcxo',
        'fmc1_enum',
        'fmc2_enum',
        'fmc1_refclk_src',
        'fmc2_refclk_src',
        'fmc1_sync_src',
        'fmc2_sync_src',
        'tclkb_mode']
    __message_id__ = 2
    __struct__ = 'BBBBBBBBBBBBBB'
    __length__ = 15

    PAYLOAD_OPTIONS = {
        'tclkb_mode' : ('none', 'acq-amc', 'amc-fpga'),
        'fpga_image' : ('a', 'b'),
        'jtag_master' : ('onboard', 'backplane'),
        'jtag_rtm' : ('disable', 'enable'),
        'acq_clk_src' : (
           'fmc2-clk1', 'fmc2-clk0', 'fmc1-clk1', 'fmc1-clk0',
           'rtm-clk', 'none'),
        'acq_clk_vcxo' : ('disable', 'enable'),
        'fmc1_enum' : ('legacy', 'mmc', 'delegated'),
        'fmc2_enum' : ('legacy', 'mmc', 'delegated'),
        'fmc1_refclk_src' :
           {0 : 'acq', 1 : 'other-fmc', 0x83 : 'none'},
        'fmc2_refclk_src' :
           {0 : 'acq', 1 : 'other-fmc', 0x83 : 'none'},
        'fmc1_sync_src' :
           {0 : 'fpga', 1 : 'other-fmc', 0x83 : 'none'},
        'fmc2_sync_src' :
            {0 : 'fpga', 1 : 'other-fmc', 0x83 : 'none'},
    }

    def format(self):
        result = [f'Payload Ver: {self.ver}']
        for key, options in self.PAYLOAD_OPTIONS.items():
            value = getattr(self, key)
            try:
                descr = options[value]
            except IndexError:
                descr = f'INVALID ({value:02x})'
            result.append(f'{key:15} = ({value:02x}) {descr}')
        return '\n'.join(result)


def read_slot(mailbox):
    '''Returns AMC slot number written by MMC to mailbox'''
    return MMC_Message.read(mailbox).slot


def read_message(mailbox, message):
    '''Reads the specified message type and returns the decoded message'''
    MESSAGES = {
        'mmc' : MMC_Message,
        'rtm' : RTM_Message,
        'payload' : PayloadMessage,
    }
    return MESSAGES[message].read(mailbox)
