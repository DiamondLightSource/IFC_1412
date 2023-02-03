# Top level makefile for IFC_1412 FPGA projects

PROJECT_TOP := $(CURDIR)

TARGET ?= test-pcie

include $(PROJECT_TOP)/CONFIG
include $(FPGA_COMMON)/Makefile.delegate

# vim: set filetype=make:
