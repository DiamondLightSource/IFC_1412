# Top level makefile for running simulation

# PROJECT_NAME = test-regs

# Boilerplate top level call.  Must include the top level CONFIG
# Once the build directory has been created this Makefile will be invoked again
# with PROJECT_TOP set to this directory.
ifndef PROJECT_TOP
include ../../../CONFIG
include $(FPGA_COMMON)/makefiles/Makefile.sim
else

BUILT += register_defines.vhd
BUILT += version.vhd
BUILT += top_entity.vhd


endif
