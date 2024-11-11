# Redirector for loading registers.py from current directory

import os

registers_py = os.path.join(os.getcwd(), 'registers.py')

# This is pretty gnarly stuff.  Pass a special globals dictionary to exec so
# that the loaded registers.py can find its own __file__ name, and we then have
# to pull out all the exports from the file we've just executed.
globs = { '__file__' : registers_py }
exec(compile(open(registers_py).read(), registers_py, 'exec'), globs)

__all__ = globs['__all__']
for name in __all__:
    globals()[name] = globs[name]
