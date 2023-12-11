# Command definitions

MRS_PREFIX = 0b10_0000_0000     # Same for rising and falling
CAT_PREFIX = 0b10_1111_0000     # Same for rising and falling

LDFF_PREFIX_R = 0b11_0000_0000
LDFF_PREFIX_F = 0b0110_000000

def MRS(m, op):
    rising  = MRS_PREFIX | ((m & 0xF) << 4) | (op & 0xF)
    falling = MRS_PREFIX | ((op >> 4) & 0xFF)
    return (rising, falling)

def CAT(command):
    command = CAT_PREFIX | ((command & 0x3) << 2)
    return (command, command)

NOP = (0b11_11111111, 0b11_11111111)

VENDOR_OFF = MRS(3, 0b00_00_00_000_000)
VENDOR_ID1 = MRS(3, 0b00_00_01_000_000)
READ_TEMPS = MRS(3, 0b00_00_10_000_000)
VENDOR_ID2 = MRS(3, 0b00_00_11_000_000)

CAT_EXIT  = CAT(0)      # Exit CAT
CAT_PASS1 = CAT(1)      # Inputs registered on rising edge
CAT_PASS2 = CAT(2)      # Inputs registered on falling edge
CAT_PASS3 = CAT(3)      # CABI_n registered on both edges

def LDFF(bank, data):
    rising  = LDFF_PREFIX_R | ((bank & 0xF) << 4) | (data & 0xF)
    falling = LDFF_PREFIX_F | ((data >> 4) & 0x3F)
    return (rising, falling)
