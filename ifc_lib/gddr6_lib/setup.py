# Helpers for managing common configuration

def check_ck_ready(sg):
    assert sg.CONFIG._value != 0xFFFFFFFF, 'Probably need to rescan PCIe bus'
    assert sg.CONFIG.CK_RESET_N, 'CK is in reset'
    assert sg.STATUS.CK_OK, 'CK is not running'

# Checks that clocks are running, the memory is not in reset, and the memory
# controller is not already running
def check_sg_ready(sg):
    check_ck_ready(sg)
    assert sg.CONFIG.SG_RESET_N == 3, 'SG still in reset'
    assert not sg.CONFIG.ENABLE_CONTROL, 'Controller is active'

def check_ctrl_ready(sg):
    check_ck_ready(sg)
    assert sg.CONFIG.SG_RESET_N == 3, 'SG still in reset'
    assert sg.CONFIG.ENABLE_CONTROL, 'Controller is inactive'


# Ensure the controller is deactivated
def disable_ctrl(sg):
    sg.CONFIG._write_fields_rw(
        ENABLE_CONTROL = 0, ENABLE_REFRESH = 0, ENABLE_AXI = 0)

def enable_ctrl(sg):
    sg.CONFIG._write_fields_rw(
        ENABLE_CABI = 1,
        ENABLE_DBI = 1,
        ENABLE_CONTROL = 1,
        ENABLE_REFRESH = 1,
        ENABLE_AXI = 1)

def set_ctrl_priority(sg, round_robin, write_priority):
    sg.CONFIG._write_fields_rw(
        PRIORITY_MODE = not round_robin,
        PRIORITY_DIR = write_priority)

def reset_training_control(sg):
    sg.CONFIG._write_fields_rw(
        ENABLE_CABI = 0,
        ENABLE_DBI = 0,
        DBI_TRAINING = 0,
        CAPTURE_EDC_OUT = 0,
        EDC_SELECT = 0)
