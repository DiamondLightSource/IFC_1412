# Discover paths to resources need by this library

import os
import re
import sys


# Returns path to top directory.
#
# This is trickier than it ought to be, as the path to __file__ may involve a
# soft link in the path.
def top_dir():
    this_file = os.path.realpath(__file__)
    return os.path.abspath(os.path.join(os.path.dirname(this_file), '..'))

def path_to(filename):
    return os.path.join(top_dir(), filename)


# Returns value of specified key in top level CONFIG directory
def get_config_key(key):
    pattern = r'%s *= *(.*)\n' % key
    for line in open(os.path.join(top_dir(), 'CONFIG'), 'r').readlines():
        match = re.fullmatch(pattern, line)
        if match:
            return match[1]
    assert False, 'Key %s not found in CONFIG file' % key


# Adds the specified path to sys.path.  The path consists of a CONFIG file key
# together with a target local component
def add_config_path(key, path = None):
    full_path = get_config_key(key)
    if path:
        full_path = os.path.join(full_path, path)
    if full_path not in sys.path:
        sys.path.append(full_path)


# Compute path to register defs for this particular test.  In general tests have
# parallel directories test/tools and test/vhd, and this is called from a file
# in tools thus:
#
#   defs = register_defines(__file__)
def register_defines(calling_file):
    here = os.path.dirname(calling_file)
    return os.path.abspath(os.path.join(here, '../vhd/register_defines.in'))

# Path to GDDR6 register defs file
def gddr6_register_defines():
    return os.path.join(top_dir(), 'gddr6/vhd/gddr6_register_defines.in')

# Path to LMK04616 register defs file
def lmk04616_defines():
    return os.path.join(top_dir(), 'lmk04616/vhd/lmk04616_defines.in')
