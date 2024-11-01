# Performs the necessary dance to access fpga_lib

try:
    import fpga_lib

except ModuleNotFoundError:
    import sys
    import os.path
    import re

    # Search for FPGA_COMMON definition in the CONFIG file and add this to our
    # path before trying the import again
    config = os.path.join(os.path.dirname(__file__), '..', 'CONFIG')
    for line in open(config).readlines():
        match = re.fullmatch(r'FPGA_COMMON *= *(.*)\n', line)
        if match:
            sys.path.append(match.group(1))
            import fpga_lib
            break
