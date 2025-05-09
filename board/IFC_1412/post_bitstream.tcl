# Create .bin files from .bit file, to be run after bitstream generation

write_cfgmem -format bin -size 128 -interface SPIx8 \
    -loadbit "up 0x00000000 top.bit" -file ../../../top.bin
