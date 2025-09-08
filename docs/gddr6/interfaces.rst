Interfaces
==========

The following interfaces are described here:

* AXI interface

* Setup register interface

* AXI to Ctrl interface

* PHY interface

* SG RAM interface

AXI interface
-------------

This is a standard AXI4 memory interface as documented in the "AMBA AXI and ACE
Protocol Specification" ARM IHI 0022.

* Bus width 512 bits (64 bytes).
* Nominal frequency 250 MHz.
* Address width 32 bits.
* Narrow bursts supported.
* Only INCR bursts supported.
* ID width 4 bits.
* Up to 64 outstanding read and write transactions.


Setup register interface
------------------------

A small register interface (9 32-bit registers) is provided to communicate with
the setup engine.


AXI to Ctrl interface
---------------------

AXI requests are converted into streams of SG bursts where a single SG burst is
a request to read or write 128 bytes of memory.  These burst are communicated
via ``axi_ctrl_{read,write}_{request,response}_t`` structures.

The exchange over this interface is pretty simple and consists of the following
elements:

* Every request has a 25 bit address identifying the location of the SG burst to
  be read or written.
* Write requests also include a 128 bit byte mask to identify which bytes need
  to be written.
* Data is transferred in the appropriate direction at a later time in response o
  appropriate control signals.
* There is also a simple lookahead in each direction to act as a hint for
  activating the bank required for the next transaction.


PHY interface (Ctrl to PHY)
---------------------------

The PHY interface consists of three structures ``phy_ca_t``, ``phy_dq_out_t``,
``phy_dq_in_t``.

``phy_ca_t`` encapsulates a single SG command.  ``phy_dq_out_t`` is just data in
PHY format together with an output enable.  ``phy_dq_in_t`` consists of data in
PHY format together with EDC information for both read and writes.



SG RAM interface
----------------

Need to describe this

Data Formats
------------

Data layout significantly changes between the four interfaces where it appears.
The layout changes are designed to support efficient handling of the data, in
particular to ensure an efficient implementation of byte writes, where it is
desireably for adjacent bytes to be written to the same SG memory bank.

AXI
    The data on the AXI bus is organised in blocks of 64 bytes.

AXI to Ctrl
    The data on the AXI to Ctrl interface is also transmitted in blocks of 64
    bytes, but the bytes are reordered to better match the SG memory bank
    structure.  This reordering is performed via the clock crossing data FIFOs
    in the AXI controller.

Ctrl to PHY
    The data on this interface is transposed into bytes representing a single CK
    tick transferring 8 bits of WCK data.  This transpose is effectively free as
    it is just a reordering of signals.

PHY to SG
    need to describe this
