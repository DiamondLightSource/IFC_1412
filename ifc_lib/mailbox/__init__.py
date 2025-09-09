# Mailbox support

import struct
from collections import namedtuple

MMC_Message = namedtuple('MMC',
    ['id', 'product', 'version', 'serial', 'slot'])


class MailboxError(Exception):
    pass


def fail(message):
    print(message, file = sys.stderr)
    raise MailboxError(message)


def read_array(mailbox, address, count):
    result = []
    for n in range(count):
        mailbox._write_fields_wo(ADDRESS = address + n, WRITE = 0)
        result.append(mailbox.DATA)
    return result


def read_mmc_message(mailbox):
    data = bytes(read_array(mailbox, 0, 10))
    if not any(data):
        fail('Nothing written to mailbox')
    if sum(data) % 256 != 0:
        fail('Invalid checksum')
    # Decode mailbox according to following structure (all number big endian):
    #   0       id, expected to be zero
    #   2:1     Product number (1412)
    #   3       Product version
    #   7:4     Product serial number
    #   8       AMC slot
    #   9       Checksum (already checked above)
    mmc = MMC_Message(*struct.unpack('>BHBLB', data[:-1]))
    if mmc.id != 0:
        fail(f'Invalid message id: {mmc.id}')
    if not 1 <= mmc.slot <= 12:
        fail(f'Invalid slot number: {mmc.slot}')
    return mmc
