# Decode CA commands

class DecodeCA:
    def __init__(self, report_nop = False):
        self.tick_count = 0
        self.mask_count = 0
        self.report_nop = report_nop

    def __decode_command(self, ca0, ca1, ca3):
        ca0_98 = ca0 >> 8
        ca1_98 = ca1 >> 8
        ca1_76 = (ca1 >> 6) & 3

        if ca0_98 == 0 or ca0_98 == 1:
            # Lx/xx -- ACT
            self.report('ACT {:X} {:04X}'.format(
                (ca0 >> 4) & 0xF,
                (ca0 & 0xF) | (ca1 << 4)))
        elif ca0_98 == 2:
            # HL/xx -- NOP/MRS/REF/PRE
            if ca1_98 == 0:
                # HL/LL -- PRE
                if (ca1 >> 4) & 1:
                    self.report('PREab')
                else:
                    self.report('PREpb {:X}'.format((ca0 >> 4) & 0xF))
            elif ca1_98 == 1:
                # HL/LH -- REF
                if (ca1 >> 4) & 1:
                    self.report('REFab')
                else:
                    self.report('REFp2b {:X}'.format((ca0 >> 4) & 0x7))
            elif ca1_98 == 2:
                # HL/HL -- MRS
                self.report('MRS {:X} {:03X}'.format(
                    (ca0 >> 4) & 0xF,
                    (ca0 & 0xF) | ((ca1 & 0xFF) << 4)))
            elif ca1_98 == 3:
                # HL/HH -- NOP
                self.nop()
        else: # 3
            # HH/xx -- NOP/others
            if ca1_98 == 0:
                # HH/LL -- WRTR/WDM/WSM/WOM
                if ca1_76 == 0:
                    # HH/LLLL -- WOM
                    self.report('WOM{:s} {:X} {:02X} {:04b}'.format(
                        'A' if (ca1 >> 4) & 1 else '',
                        (ca0 >> 4) & 0xF,
                        (ca0 & 0xF) | ((ca1 & 7) << 4),
                        ca3))
                elif ca1_76 == 1:
                    # HH/LLLH -- WSM
                    self.report('WSM{:s} {:X} {:02X} {:04b}'.format(
                        'A' if (ca1 >> 4) & 1 else '',
                        (ca0 >> 4) & 0xF,
                        (ca0 & 0xF) | ((ca1 & 7) << 4),
                        ca3))
                    self.mask_count = 2
                elif ca1_76 == 2:
                    # HH/LLHL -- WDM
                    self.report('WDM{:s} {:X} {:02X} {:04b}'.format(
                        'A' if (ca1 >> 4) & 1 else '',
                        (ca0 >> 4) & 0xF,
                        (ca0 & 0xF) | ((ca1 & 7) << 4),
                        ca3))
                    self.mask_count = 1
                elif ca1_76 == 3:
                    # HH/LLHH -- WRTR
                    self.report('WRTR')
            elif ca1_98 == 1:
                # HH/LH -- RDTR/LDFF/RD
                if ca1_76 == 0:
                    # HH/LHLL -- RD
                    self.report('RD{:s} {:X} {:02X}'.format(
                        'A' if (ca1 >> 4) & 1 else '',
                        (ca0 >> 4) & 0xF,
                        (ca0 & 0xF) | ((ca1 & 7) << 4)))
                elif ca1_76 == 1:
                    # HH/LHLH -- invalid coding
                    self.report('UNKNOWN')
                elif ca1_76 == 2:
                    # HH/LHHL -- LDFF
                    self.report('LDFF {:X} {:03X}'.format(
                        (ca0 >> 4) & 0xF,
                        (ca0 & 0xF) | (ca1 & 0x3F) << 4))
                elif ca1_76 == 3:
                    # HH/LHHH -- RDTR
                    self.report('RDTR')
            elif ca1_98 == 2 or ca1_98 == 3:
                # HH/Hx -- NOP
                self.nop()

    def __decode_mask(self, ca0, ca1):
        if ca0 >> 8 == 3 and ca1 >> 8 == 3:
            # Complement mask to show bytes being written as 1s
            self.report('mask: {:04X}'.format(
                (~ca0 & 0xFF) | ((~ca1 & 0xFF) << 8)))
        else:
            self.report('Malformed mask {:03X}:{:03X}'.format(ca0, ca1))
        self.mask_count -= 1

    def decode(self, ca):
        if self.mask_count > 0:
            self.__decode_mask(ca.RISING, ca.FALLING)
        else:
            self.__decode_command(ca.RISING, ca.FALLING, ca.CA3)
        self.tick_count += 1

    def report(self, string):
        print('@{:2d}  {:s}'.format(self.tick_count, string))

    def nop(self):
        if self.report_nop:
            report('NOP')
