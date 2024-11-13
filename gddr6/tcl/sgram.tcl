# Special constraint for SG RAM
#
# Note that at present this is included in the IP build but is not recommended
# for use in the target build: it seems that adding CK to the same clock delay
# group changes the timing of the bitslice receiver.


# Only apply these special constraints to the SG DRAM MMCM as named below
set mmcm [get_cells -hier -filter {
    NAME =~ */sg_dram_mmcm && REF_NAME == MMCME3_ADV }]
if [llength $mmcm] {
    # Align ck_clk_delay (on CLKOUT0) and ck_clk (on CLKOUT1) with input CK
    set pins [get_pins [list $mmcm/CLKFBOUT $mmcm/CLKOUT0 $mmcm/CLKOUT1]]

    # Walk from pins through the attached BUFGCE to get the associated nets
    set bufg [get_cell -of [get_pins -of [get_nets -of $pins] -filter {
        DIRECTION == IN && REF_NAME == BUFGCE }]]
    set nets [get_nets -of [get_pins -of $bufg -filter { DIRECTION == OUT }]]

    set_property CLOCK_DELAY_GROUP SG_CLOCKING $nets
}
