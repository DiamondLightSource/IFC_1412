# Top level makefile for IFC_1412 FPGA projects

PROJECT_TOP := $(CURDIR)

include $(PROJECT_TOP)/CONFIG
include $(FPGA_COMMON)/makefiles/Makefile.delegate

# vim: set filetype=make:
