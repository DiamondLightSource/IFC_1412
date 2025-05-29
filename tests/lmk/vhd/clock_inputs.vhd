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
    signal sg_clocks : sg_p_i'SUBTYPE;
    signal lvds_clocks : lvds_p_i'SUBTYPE;
    signal mgt_clocks : mgt_p_i'SUBTYPE;

begin
    sg : entity work.ibufds_array generic map (
        COUNT => sg_clocks'LENGTH,
        -- Don't set differential termination for SG clocks as these have their
        -- termination set separately in the constraints file
        DIFF_TERM => false
    ) port map (
        p_i => sg_p_i,
        n_i => sg_n_i,
        o_o => sg_clocks
    );

    lvds : entity work.ibufds_array generic map (
        COUNT => lvds_clocks'LENGTH
    ) port map (
        p_i => lvds_p_i,
        n_i => lvds_n_i,
        o_o => lvds_clocks
    );

    mgt : for i in mgt_clocks'RANGE generate
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
            O => mgt_clocks(i)
        );
    end generate;

    clocks_o <= sg_clocks & lvds_clocks & mgt_clocks;
end;
