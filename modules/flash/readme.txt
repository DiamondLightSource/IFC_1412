This module is designed to be loaded into the secondary configuration memory
and should be used for programming the primary configuration.

The following information is required to configure the memory:

    $build_dir
        Location of the FPGA build directory.  This directory should contain two
        files, top_primary.bin, top_secondary.bin.

    $mch
        Network path to MCH controller for the MTCA crate containing the AMC
        card to be configured.

    $amc
        Slot number of the AMC card in the form amc$n where $n is the actual
        card number (eg, amc4).

    $mtca_server
        Name of server with PCIe backplane connection to AMC card.

The following scripts should be on the path (or can be run from their
respective directories):

    ifc1412                             in IFC_1412/tools directory
    rescan-pci                          in AmcPciDev/tools directory
    check-flash, write-config, verify   in tools directory in this project

Source the pythonpath file in the tools directory before attempting to run any
of the flash tools.


To get the AMC card ready for reprogramming run the following steps:

1.  Reboot the FPGA into the secondary configuration

        ifc1412 $mch $amc set fpga-config b
        ifc1412 $mch $amc reset fpga
        ifc1412 $mch $amc get fpga-state

    This last command should return configured

2.  Select the primary configuration for programming

        ifc1412 $mch $amc set fpga-config a

    Note that this state cannot be read back, the setting returned by invoking

        ifc1412 $mch $amc get payload-config

    is the state that will be loaded when the system is restarted.  This should
    normally also be set to fpga-image=a

3.  Log into $mtca_server and rescan the PCI bus by running

        rescan-pci

    As a sanity check it would make sense to run

        ls /dev/ifc_1412-flash.*

    to check whether the required node has appeared and whether it is configured
    as node 0.

4.  Check that the flash memories are communicating properly by running the
    command

        check-flash

    If the device node is not node 0 then the -a argument should be used, eg

        check-flash -a 1

    to access /dev/ifc_1412.1.reg.  The output from this command should look
    like this:

        user ok 00 00 00 00000000
        125M  0 0 1 1 0 0 0 0
        63M   0 0 1 1 1 1 0 0
        42M   0 0 1 1 1 1 1 1
        31M   0 0 1 1 1 1 1 1

        fpga1 ok 00 00 00 00000000
        125M  0 0 1 1 0 0 0 0
        63M   0 0 1 1 1 1 0 0
        42M   0 0 1 1 1 1 1 1
        31M   0 0 1 1 1 1 1 1

        fpga2 ok 00 00 00 00000000
        125M  0 0 1 1 0 0 0 0
        63M   0 0 1 1 1 1 0 0
        42M   0 0 1 1 1 1 1 1
        31M   0 0 1 1 1 1 1 1

5.  Copy the .bin files from $build_dir to $mtca_server:

        scp $build_dir/top_*.bin $mtca_server:/tmp

6.  Program the configuration:

        write-config /tmp/top_primary.bin /tmp/top_secondary.bin

    and verify with

        verify -s fpga1 /tmp/top_primary.bin
        verify -s fpga2 /tmp/top_secondary.bin

7.  Load the new configuration with commands

        ifc1412 $mch $amc reset fpga
        rescan-pci
