# Commands for talking to SG RAM

from collections import namedtuple
import numpy

from .commands import NOP



class _Exchange:
    _instance = [None]

    def __init__(self, sg):
        assert self._instance[0] is None, \
            'Cannot create multiple Exchange instances'
        self.sg = sg
        self.reset()
        self._instance[0] = self

    def discard(self):
        del self.sg
        self._instance[0] = None

    def reset(self):
        self.sg.COMMAND._write_fields_wo(START_WRITE = 1)
        self.count = 0
        self.exchanged = False


    def command(self, command, cke_n = 0, ca3 = 0, oe = 0):
        assert self.count < 64, 'Command buffer is full'
        assert not self.exchanged, 'Must reset before refilling'
        self.sg.CA._write_fields_wo(
            RISING = command[0], FALLING = command[1],
            CA3 = ca3, CKE_N = cke_n, OUTPUT_ENABLE = oe)
        self.count += 1

    # Writes the requested number of NOPs
    def delay(self, delay):
        for n in range(delay):
            self.command(NOP)

    # Performs a simple exchange
    def exchange(self):
        assert self.count > 0, 'No data to exchange'
        self.exchanged = True
        self.sg.COMMAND._write_fields_wo(EXCHANGE = 1)

    def read_data(self):
        assert self.exchanged, 'No data to read'
        self.sg.COMMAND._write_fields_wo(START_READ = 1)
        data = numpy.empty((self.count, 16), dtype = numpy.uint32)
        for i in range(self.count):
            for j in range(16):
                data[i, j] = self.sg.DQ._value
            self.sg.COMMAND._write_fields_wo(STEP_READ = 1)
        return data.view('uint8')

    def read_edc(self):
        assert self.exchanged, 'No data to read'
        self.sg.COMMAND._write_fields_wo(START_READ = 1)
        edc_in = numpy.empty((self.count, 2), dtype = numpy.uint32)
        edc_out = numpy.empty((self.count, 2), dtype = numpy.uint32)
        for i in range(self.count):
            for j in range(2):
                edc_in[i, j] = self.sg.EDC_IN._value
                edc_out[i, j] = self.sg.EDC_OUT._value
            self.sg.COMMAND._write_fields_wo(STEP_READ = 1)
        return (edc_in.view('uint8'), edc_out.view('uint8'))

    def run(self):
        self.exchange()
        return self.read_data()


    # Simply sets the CA output state by running a single command
    def set_ca(self, command, cke_n):
        self.reset()
        self.command(command, cke_n)
        self.exchange()
