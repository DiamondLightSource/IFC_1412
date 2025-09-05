Design Notes
============

Overview
--------

..  figure:: build/figures/gddr6-overview.png

    Memory controller overview

The memory controller is structured into four components:

phy
    This manages the interface to the physical IOs and clock generation and
    distribution.

setup
    This provides a register interface which is used to manage the phy and
    manage link training.

ctrl
    This manages the command interface to the memory.

axi
    This provides the AXI bus interface to the memory controller.


Phy
---

Nothing here het

Setup
-----

Nothing here yet

Ctrl
----

..  figure:: build/figures/ctrl-overview.png

    Overview of controller

..  figure:: build/figures/data-timing.png

    Aligning data events

..  figure:: build/figures/request.png
..  figure:: build/figures/request.old.png

AXI
---

..  figure:: build/figures/axi-read.png

    Read interface to memory controller.

..  figure:: build/figures/axi-write.png

    Write interface to memory controller.

Misc
----

..  figure:: build/figures/sg-termination.png
