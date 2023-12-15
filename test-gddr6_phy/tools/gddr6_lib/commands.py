# Command definitions


# A number of CA commands require holding the same state over both edges
def DWELL(command):
    return (command, command)

# Special reset state commands, these need to be held as the corresponding SG
# device is brought out of reset.  Each CA line (except for CA(3)) is brought to
# all four channels, so we terminate with channels AB on SG2 at 120 Ohm per
# channel.  The CA(3) lines need separate termination with 120 Ohm extra for SG2
# and 60 Ohm for SG1.  The CK signal is terminated with 60 Ohm on SG2.
#
#  1:0  Channel A CA ODT: 00 => high impedance, 01 => 120 Ohm
#  3:2  Channel B CA ODT, as above
#  5:4  CK ODT, 00 => high impedance, 10 => 60 Ohm
#  6    1 => 2 channel mode
#                          6  4  2  0
RESET_SG1_CA = DWELL(0b111_1_00_00_00)  # SG1: all inputs high impedance
RESET_SG2_CA = DWELL(0b111_1_10_01_01)  # SG2: CK @ 60 Ohm, CA @ 120 Ohm

# NOP command for use when otherwise idle
NOP = DWELL(0b11_11111111)


# Command for setting Mode register
def MRS(m, op):
    MRS_PREFIX = 0b10_0000_0000     # Same for rising and falling
    rising  = MRS_PREFIX | ((m & 0xF) << 4) | (op & 0xF)
    falling = MRS_PREFIX | ((op >> 4) & 0xFF)
    return (rising, falling)

# Special command for CA training (actually an MRS command)
def CAT(command):
    CAT_PREFIX = 0b10_1111_0000     # Same for rising and falling
    return DWELL(CAT_PREFIX | ((command & 0x3) << 2))


# Special commands for reading Vendor ID and temperature
VENDOR_OFF = MRS(3, 0b00_00_00_000_000)
VENDOR_ID1 = MRS(3, 0b00_00_01_000_000)
READ_TEMPS = MRS(3, 0b00_00_10_000_000)
VENDOR_ID2 = MRS(3, 0b00_00_11_000_000)

# CA training commands
CAT_EXIT  = CAT(0)      # Exit CAT
CAT_PASS1 = CAT(1)      # Inputs registered on rising edge
CAT_PASS2 = CAT(2)      # Inputs registered on falling edge
CAT_PASS3 = CAT(3)      # CABI_n registered on both edges



# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Mode register definitions for initialisation

#  2:0  WLmrs   Write latency, can be 5/6/7
#  6:3  RLmrs   Read latency, can be from 9 to 20 (add 5 to written value)
# 11:8  WR      Write recovery for auto precharge, MSB in MR8.  Value can be
#               from 4 to 35 (add 4 to written value)
#                   11 :8   6 :3 2:0
INIT_MR0  = MRS(0, 0b0001_0_0100_101)

#  1:0  Driver strength, set to 40/50 Ohms
#  3:2  Data termination, set to 60 Ohms
#  5:4  PLL range, unused
#  6    Enable calibration on REFab commands (0 => on)
#  7    PLL disabled (0 => PLL off)
#  8    RDBI used to enable DBI on reads (0 => on)
#  9    WDBI used to enable DBI on writes (0 => on)
# 10    CABI enables bus inversion on CA, needed for prototype board (0 => on)
# 11    PLL reset, unused
#                     10 9 8 7 6  4  2  0
INIT_MR1  = MRS(1, 0b0_0_0_0_0_0_00_01_00)

#  2:0  On chip pulldown driver offset
#  5:3  On chip pullup driver offset
#  7:6  Self refresh set to 32 ms
#  8    Full data rate EDC output selected
#  9    Disable RDQS mode (want EDC enabled)
# 10    Enable self refresh during CA training (does this matter?)
# 11    Controls EDC hold pattern output (1 => half data rate pattern)
#                   11   9 8  6 5:3 2:0
INIT_MR2  = MRS(2, 0b0_1_0_1_00_000_000)

#  2:0  Data and WCK termination offset
#  5:3  CA termination offset
#  7:6  Used to read DRAM info registers
#  9:8  Part of write recovery scaling
# 11:10 Bank groups off
#                    10  8  6 5:3 2:0
INIT_MR3  = MRS(3, 0b00_00_00_000_000)

#  3:0  EDC hold pattern, transmitted when EDC idle
#  6:4  CRC write latency 10-14 (add 7 to written value)
#  8:7  CRC read latency, can only be 2
#  9    RDCRC Enable Read CRC (0 => on)
# 10    Enable Write CRC (0 => on)
# 11    Set to invert EDC hold pattern
#                     10 9  7 6:4 3 :0
INIT_MR4  = MRS(4, 0b0_0_0_10_011_1110)

#  1    LP2 allows WCK to turn off
#  2    LP3 enable training during REFab, needed for read training
#  4:3  PLL bandwidth, unused
# 11:6  RAS delay, must be at least 7 for 250 MHz CK clock
#                    11 : 6    3 2 1
INIT_MR5  = MRS(5, 0b000111_0_00_0_0_0)

# MR6 is a bit special, each write selects a different pin or group of pins
#  6:0  VREFD level or TX EQ enable
# 11:7  Pin selection (0F => Byte 0, 1F => Byte 1, 0A => TX EQ B0, 1A => Byte 1)
INIT_MR6_B0_VREF = MRS(6, 0b01111_0101111)  # Set VREFD = 0.725 V
INIT_MR6_B1_VREF = MRS(6, 0b11111_0101111)
INIT_MR6_B0_TXEQ = MRS(6, 0b01010_0000000)  # Disable output equalisation
INIT_MR6_B1_TXEQ = MRS(6, 0b11010_0000000)

#  0    Define WCK2CK alignment point, 1 => on external pins
#  1    Set to 1 to enter hibernate on next refresh
#  2    PLL delay compensation, probably not supported
#  3    Low frequency mode (1 => fCK <= 250 MHz)
#  4    Enables WCK2CK auto synchronisation
#  5    DQ Preamble, probably not supported
#  6,7  Enable half VREFC/VREFD modes
#                         7 6   4 3 2 1 0
INIT_MR7  = MRS(7, 0b0000_0_0_0_1_1_0_0_1)

#  1:0  CA[3:0] termination (disabled by MR8:4)
#  3:2  CA[9:4] termination (disabled by MR8:4)
#  4    Leave 0 to used CA ODT value at reset
#  5    Sets EDC tri-state (1 => tri-state)
#  6    Enable CK ODT auto termination
#  7    Controls number of banks: 0 => REFpb, 1 => REFp2b
#  8,9  Field extensions to MR0[6:3] and MR0[11:8] respectively
#                       9 8 7 6 5 4  2  0
INIT_MR8  = MRS(8, 0b00_0_0_1_1_0_0_00_00)

# MR9 is similar to MR6
#  3:0  Decision feedback equalisation, set to smallest step by IOxOS
# 11:7  Pin selection (0F => Byte 0, 1F => Byte 1)
INIT_MR9_B0_DEF = MRS(9, 0b01111_000_0001)  # Equalise with 7mV shift
INIT_MR9_B1_DEF = MRS(9, 0b11111_000_0001)

#  3:0  VREFC offset.  Don't think we use this, can leave as zero
#  5:4,7:6  WCK phase shift for training
#  8    Set to enable WCK2CK training
#  9    WCK ratio: 0 => half data rate (DDR)
# 11:10 WCK termination, disabled as terminated off-die
#                            10 9 8  6  4 3 :0
INIT_MR10        = MRS(10, 0b00_0_0_00_00_0000)
INIT_MR10_WCK2CK = MRS(10, 0b00_0_1_00_00_0000)

#  1    P2BR address: selects don't care bit for REFp2b (0 => LSB, 1 => MSB)
#                                1
INIT_MR12 = MRS(12, 0b0000000000_1_0)



# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Other miscellaneous commands


# Loads 10 bits of data into the selected burst of the read FIFO
def LDFF(burst, data):
    LDFF_PREFIX_R = 0b11_0000_0000
    LDFF_PREFIX_F = 0b0110_000000
    rising  = LDFF_PREFIX_R | ((burst & 0xF) << 4) | (data & 0xF)
    falling = LDFF_PREFIX_F | ((data >> 4) & 0x3F)
    return (rising, falling)

# Read training command
RDTR = (0b11_1111_1111, 0b01_1110_1111)

# Write training command
WRTR = (0b11_1111_1111, 0b00_1111_1111)

# Precharge all banks
PREab = (0b10_1111_1111, 0b00_1110_1111)

# Refresh all banks
REFab = (0b10_1111_1111, 0b01_1111_1111)
