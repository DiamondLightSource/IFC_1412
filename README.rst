Firmware support for IFC_1412
=============================

This repository contains:

*   SG GDDR6 memory controller for IFC_1412 card
*   Support libraries for controlling firmware resources
*   Test builds for investigating resources

To use the memory controller:

*   Edit the `CONFIG` file appropriately
*   Run make in the `gddr6` directory to build an IP wrapper
*   Run make in the `test-gddr6_ip` directory to build an example application
*   Run `tools/setup-lmk` followed by `tools/setup-sgram` to initialise the
    memory

Please refer to the discussion in
https://github.com/DiamondLightSource/IFC_1412/discussions/1 for more detailed
instructions and a channel for feedback.

The following repositories are dependencies:

https://github.com/DiamondLightSource/fpga-common/
    This provides resources needed by all the commands above

https://github.com/DiamondLightSource/AmcPciDev
    This provides the device supported needed to communicated with the example
    firmware

This project remains work in progress and may change substantially without any
notice.
