# Helper functions for displaying captured data

import numpy


# Condenses a single byte into 0/1 or X if not a consistent single value
def condense_byte(value):
    if value == 0xFF:
        return '1'
    elif value == 0:
        return '0'
    else:
        return 'X'


# Converts a single row of dq data into 4 16-bit values
def condense_data(dq):
    ones = dq == 0xFF
    zeros = dq == 0
    good = ones | zeros

    bits = 2**numpy.arange(16, dtype = numpy.uint16)
    words = ones.reshape((4, 16))
    values = (words * bits).sum(1)
    good = good.reshape((4, 16)).all(1)
    return (values, good)

def condense_edc(edc):
    ones = edc == 0xFF
    zeros = edc == 0
    good = ones | zeros

    bits = 2**numpy.arange(8, dtype = numpy.uint8)
    values = (ones * bits).sum()
    good = good.all()
    return (values, good)


def print_condensed_data(data, offset = 0):
    for n, dq in enumerate(data[offset:]):
        result = []
        for channel in range(4):
            selection = dq[16*channel : 16*(channel + 1)]
            result.append(''.join(map(condense_byte, selection)))
        values, good = condense_data(dq)
        print('%2d:' % (n + offset), ' '.join(result), ' ',
            ' '.join(['%04X' % v if g else '----'
                for v, g in zip(values, good)]))

def print_condensed_data_edc(data, dbi, edc, offset = 0):
    for n, (dq, di, eo) in enumerate(zip(data[offset:], dbi, edc)):
        result = []
        for channel in range(4):
            selection = dq[16*channel : 16*(channel + 1)]
            result.append(''.join(map(condense_byte, selection)))
        data, data_good = condense_data(dq)
        e_in, e_in_good = condense_edc(di)
        e_out, e_out_good = condense_edc(eo)
        print('%2d:' % (n + offset), ' '.join(result), ' ',
            ' '.join(['%04X' % v if g else '----'
                for v, g in zip(data, data_good)]), ' '
            '%02X' % e_in if e_in_good else ' --',
            '%02X' % e_out if e_out_good else '--')

def print_condensed_data_dbi(data, dbi, offset = 0):
    for n, (dq, di) in enumerate(zip(data[offset:], dbi)):
        result = []
        for channel in range(4):
            selection = dq[16*channel : 16*(channel + 1)]
            result.append(''.join(map(condense_byte, selection)))
        data, data_good = condense_data(dq)
        e_in, e_in_good = condense_edc(di)
        print('%2d:' % (n + offset), ' '.join(result), ' ',
            ' '.join(['%04X' % v if g else '----'
                for v, g in zip(data, data_good)]), ' '
            '%02X' % e_in if e_in_good else ' --')
