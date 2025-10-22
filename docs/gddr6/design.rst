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

After reset and during link training the controller is disabled, the AXI link
is stalled, and setup is in control of phy.  After link training is successfully
completed setup hands control over to the controller and enables it.


Phy
---

This performs the following functions:

* Clocking and reset.  The main controller clock is the CK clock at 250 MHz and
  a specific reset sequence needs to be followed to properly initialise the
  hardware resources.
* Mapping of hardware resources to pins.  This involves the instantiation and
  configuration of the FPGA BITSLICE components.
* Control over fine delay of the input and output signals, needed for detailed
  link training.
* Computation of Error Detection Code (EDC) CRC needed for validation of valid
  data transfer.

Setup
-----

Provides a register interface to communicate with the Phy.  Can perform up to 64
CK ticks of transfer on command and is used to perform link training.

At some point this will be replaced by automatic link training.

Ctrl
----

The controller receives individual SG transfer requests, both for reading and
writing, and generates the appropriate SG commands and data timing signals.

..  figure:: build/figures/ctrl-overview.png

    Overview of controller

The main function of the controller is to manage the state of the 16 available
banks and to generate read and write SG commands as requested.

The components show above can be briefly described:

read
    This entity simply remaps read SG requests from the AXI controller into
    ``core_request_t`` packets ready to be processed.
write
    Maps write SG requests into up to four ``core_request_t`` packets.  This
    mapping is required in order to correctly handle write requests with complex
    byte enable patterns.
mux
    Chooses whether to forward read or write requests to the request handler.
    This has some hysteresis and a small delay in switching direction to allow
    for the fact that switching between read and writes to memory takes time.
request
    This is a four stage pipeline used to ensure that the memory is ready to
    handle the read or write request that is being issued.  The first two stages
    are used to ensure that the associated bank is activated for the correct row
    (one stage to present the request, one to receive the response), the final
    two stages are used to wait for the bank to be ready.

    Commands are finally sent to the memory and a completion signal to the data
    transfer engine ensures that data is transferred in the appropriate
    direction at the correct time.
banks
    This manages the state of all 16 memory banks, keeping track of the
    activation state and associated row for each bank, and any associated delays
    that need to be managed.
lookahead
    Issues a request to open a bank when an upcoming transaction in the
    currently active direction is detected.
refresh
    Manages the refresh state of all 16 banks.  Issues refresh requests for all
    banks, making an effort to avoid refreshing currently active banks unless
    necessary, and issuing a full refresh every millisecond.
admin
    On request issues commands to activate, precharge, and refresh banks.  These
    commands are mostly interleaved with read and write requests.
data
    Manages the detailed timing of data transfers and reshapes data passing
    through as required.  The timing alignment required is illustrated in the
    figure below.

    ..  figure:: build/figures/data-timing.png

        Aligning data events

    The delays shown are a combination of memory delays (shown along the top)
    and internal delays.

Request Pipeline
................

The request pipeline turned out to be surprisingly complex and is worth
describing in more detail.  The figure below shows the detailed structure of
this:

..  figure:: build/figures/request.png
    :width: 60%

The input from ``mux`` has a skid buffer to provide a registered boundary for
the combinatorial pipeline ready chain.  Commands are then fed into the four
stage pipeline shown with ready flags propagating upwards from the bottom.

The table below shows the detailed meaning of the symbols used for the pipeline
stage.  The guard input is set to 1 if not required.  Notice the combinatorial
propagation of the ready chain.

=============== ================================================================
Symbol          Detail
=============== ================================================================
|pipeline|      |pipeline-detail|
=============== ================================================================

..  |pipeline| image:: build/figures/pipeline.png
..  |pipeline-detail| image:: build/figures/pipeline-detail.png



AXI
---

AXI presents five streamed interfaces for memory interfacing:

AR
    A read request consists of a start address and a burst length together with
    other packet framing information.
R
    Read data is streamed in response to an AR read request, the packet length
    is determined by the request.
AW
    Similarly a write request consists of a start address, burst length, and
    packet framing.
W
    Write data is streamed with the burst length determined by the associated AW
    write request.
B
    When a write is fully completed, in this case this includes verification of
    successful write to memory, a B response is returned.

Reads and writes are completely independent.  The figures below show the
structure of the AXI read and write controllers.

..  figure:: build/figures/axi-read.png

    Read interface to memory controller.

..  figure:: build/figures/axi-write.png

    Write interface to memory controller.

The symbols on the connections show flow control as described in the key below.

..  list-table::
    :header-rows: 1

    * - Symbol
      - Description
    * - |symbol-flow|
      - This symbol on a line indicates that this is a flow controlled path with
        full AXI style ready/valid handshaking.  This can optionally be combined
        with either or both of the following two symbols.
    * - |symbol-frame|
      - This symbol indicates that the flow is framed into bursts using the
        ``last`` indicator.
    * - |symbol-burst|
      - This indicates a flow which must be capable of flowing without data
        bubbles, in particular both ends must be capable of streaming data with
        a fresh transaction on every tick when appropriate.
    * - |symbol-all|
      - This combines the symbols above into a standard data burst.
    * - |symbol-ready|
      - This indicates a flow where only the ready signal is used.  The sender
        must have valid data available when ready is asserted.
    * - |symbol-valid|
      - This indicates a flow where only the valid signal is used.  The receiver
        must be either always be ready, or some readyness must be ensured
        through some other mechanism.


..  |symbol-flow| image:: build/figures/symbol-flow.png
..  |symbol-frame| image:: build/figures/symbol-frame.png
..  |symbol-burst| image:: build/figures/symbol-burst.png
..  |symbol-all| image:: build/figures/symbol-all.png
..  |symbol-ready| image:: build/figures/symbol-ready.png
..  |symbol-valid| image:: build/figures/symbol-valid.png

Misc
----

..  figure:: build/figures/sg-termination.png
