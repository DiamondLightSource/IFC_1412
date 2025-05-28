-- Input definitions for clocks

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity clock_inputs is
    port (
        sg_p_i : in std_ulogic_vector;
        sg_n_i : in std_ulogic_vector;
        lvds_p_i : in std_ulogic_vector;
        lvds_n_i : in std_ulogic_vector;
        mgt_p_i : in std_ulogic_vector;
        mgt_n_i : in std_ulogic_vector;

        clocks_o : out std_ulogic_vector
    );
end;

architecture arch of clock_inputs is
    constant SG_COUNT : natural := sg_p_i'LENGTH;
    constant LVDS_COUNT : natural := lvds_p_i'LENGTH;
    constant MGT_COUNT : natural := mgt_p_i'LENGTH;
    constant MGT_OFFSET : natural := SG_COUNT + LVDS_COUNT;
    subtype SG_RANGE is natural range 0 to SG_COUNT - 1;
    subtype LVDS_RANGE is natural range SG_COUNT to MGT_OFFSET - 1;
    subtype MGT_RANGE is natural range MGT_OFFSET to MGT_OFFSET + MGT_COUNT - 1;

begin
    sg_clocks : entity work.ibufds_array generic map (
        COUNT => SG_COUNT,
        -- Don't set differential termination for SG clocks as these have their
        -- termination set separately in the constraints file
        DIFF_TERM => false
    ) port map (
        p_i => sg_p_i,
        n_i => sg_n_i,
        o_o => clocks_o(SG_RANGE)
    );

    lvds_clocks : entity work.ibufds_array generic map (
        COUNT => LVDS_COUNT
    ) port map (
        p_i => lvds_p_i,
        n_i => lvds_n_i,
        o_o => clocks_o(LVDS_RANGE)
    );

    mgt_clocks : for i in 0 to MGT_COUNT-1 generate
        signal odiv2 : std_ulogic;
    begin
        ibuf : IBUFDS_GTE3 port map (
            I => mgt_p_i(i),
            IB => mgt_n_i(i),
            CEB => '0',
            O => open,
            ODIV2 => odiv2
        );
        bufg : BUFG_GT port map (
            CE => '1',
            CEMASK => '1',
            CLR => '0',
            CLRMASK => '1',
            DIV => "000",
            I => odiv2,
            O => clocks_o(MGT_OFFSET + i)
        );
    end generate;
end;
