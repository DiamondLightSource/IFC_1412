# Helper functions for driving SG exchange

import numpy

from registers import sg


def to_string(array):
    assert array.ndim == 1
    return '[' + ' '.join(['%02X' % a for a in array]) + ']'

def header_string(count):
    return ' '.join('%2d' % n for n in range(count))

def print_header(show_edc_in = False, show_edc_out = False, dq_count = 64):
    header = [header_string(dq_count)]
    if show_edc_in:
        header.extend([' ', header_string(8)])
    if show_edc_out:
        header.extend([' ', header_string(8)])
    print('    ', ' '.join(header))



class Exchange:
    def __init__(self, count = None, dq_count = 64):
        if count is not None:
            self.init(count, dq_count)

    def init(self, count, dq_count = 64):
        assert dq_count % 4 == 0
        self.count = count
        self.dq_count = dq_count
        self.ca = numpy.empty(count, dtype = numpy.uint32)
        self.ca[:] = 0xFFFFF
        self.ca3 = numpy.zeros(count, dtype = numpy.uint8)
        self.dqt = numpy.ones(count, dtype = numpy.bool)
        self.cke_n = numpy.zeros(count, dtype = numpy.bool)
        self.dq = numpy.empty((count, dq_count), dtype = numpy.uint8)
        self.dq[:,:] = 0xFF

    def exchange(self):
        # Write the data to be sent
        sg.COMMAND._write_fields_wo(START_WRITE = 1)
        for ca, ca3, dqt, cke_n, dq in \
                zip(self.ca, self.ca3, self.dqt, self.cke_n, self.dq):
            for d in dq.view('uint32'):
                sg.DQ._value = d
            sg.CA._write_fields_wo(
                RISING = ca & 0x3FF, FALLING = (ca >> 10) & 0x3FF,
                CA3 = ca3, CKE_N = cke_n, DQ_T = dqt)

        # Exchange
        sg.COMMAND._write_fields_wo(EXCHANGE = 1, START_READ = 1)

        # Read the data
        count = self.count
        data = numpy.empty((count, self.dq_count//4), dtype = numpy.uint32)
        edc_in = numpy.empty((count, 2), dtype = numpy.uint32)
        edc_out = numpy.empty((count, 2), dtype = numpy.uint32)
        for i in range(count):
            for j in range(self.dq_count//4):
                data[i, j] = sg.DQ._value
            for j in range(2):
                edc_in[i, j] = sg.EDC_IN._value
                edc_out[i, j] = sg.EDC_OUT._value
            sg.COMMAND._write_fields_wo(STEP_READ = 1)

        # Hang onto the results
        self.data = data.view('uint8')
        self.edc_in = edc_in.view('uint8')
        self.edc_out = edc_out.view('uint8')

    def print(self, show_edc_in = False, show_edc_out = False):
        for n, (dq, edc_in, edc_out) in \
                enumerate(zip(self.data, self.edc_in, self.edc_out)):
            print('%2d:' % n, to_string(dq), end = '')
            if show_edc_in:
                print('', to_string(edc_in), end = '')
            if show_edc_out:
                print('', to_string(edc_out), end = '')
            print()


def do_exchange(ca, dqt, dq, count, dq_count = 64):
    exchange = Exchange(count, dq_count)
    exchange.ca[:len(ca)] = numpy.array(ca)
    exchange.dqt[:len(dqt)] = numpy.array(dqt)
    exchange.dq[:len(dq)] = dq
    exchange.exchange()
    return exchange
