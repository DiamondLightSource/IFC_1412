# Control over delays

TARGET_IDELAY = 0
TARGET_ODELAY = 1
TARGET_IBITSLIP = 2
TARGET_OBITSLIP = 3


def step_delay(sg, target, address, amount):
    if amount == 0:
        return
    elif amount < 0:
        up_down_n = 0
        amount = - amount
    else:
        up_down_n = 1
    sg.DELAY._write_fields_wo(
        ADDRESS = address, TARGET = target,
        DELAY = amount - 1, UP_DOWN_N = up_down_n,
        ENABLE_WRITE = 1)

def read_delay(sg, target, address):
    sg.DELAY._write_fields_wo(
        ADDRESS = address, TARGET = target, ENABLE_WRITE = 0)
    return sg.DELAY.DELAY


def step_phase(sg, up_down_n):
    sg.DELAY._write_fields_wo(UP_DOWN_N = up_down_n, STEP_PHASE = 1)

def advance_phase(sg, amount):
    if amount >= 0:
        up_down_n = 1
    else:
        up_down_n = 0
        amount = - amount
    for i in range(amount):
        step_phase(sg, up_down_n)

def read_phase(sg):
    phase = sg.DELAY.PHASE
    if phase >= 112:
        phase -= 224
    return phase

def set_phase(sg, target):
    delta = target - read_phase(sg)
    if delta > 112:
        delta -= 224
    elif delta < -112:
        delta += 224
    advance_phase(sg, delta)



def set_idelay(sg, address, delay):
    step_delay(sg, TARGET_IDELAY, address, delay - read_idelay(sg, address))

def set_odelay(sg, address, delay):
    step_delay(sg, TARGET_ODELAY, address, delay - read_odelay(sg, address))

def set_ibitslip(sg, address, delay):
    sg.DELAY._write_fields_wo(
        ADDRESS = address, TARGET = TARGET_IBITSLIP,
        DELAY = delay, ENABLE_WRITE = 1)

def set_obitslip(sg, address, delay):
    sg.DELAY._write_fields_wo(
        ADDRESS = address, TARGET = TARGET_OBITSLIP,
        DELAY = delay, ENABLE_WRITE = 1)


def read_idelay(sg, address):
    return read_delay(sg, TARGET_IDELAY, address)

def read_odelay(sg, address):
    return read_delay(sg, TARGET_ODELAY, address)

def read_ibitslip(sg, address):
    return read_delay(sg, TARGET_IBITSLIP, address)

def read_obitslip(sg, address):
    return read_delay(sg, TARGET_OBITSLIP, address)
