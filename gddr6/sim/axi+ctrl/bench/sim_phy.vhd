library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_ctrl_command_defs.all;

entity sim_phy is
    port (
        clk_i : in std_ulogic;

        ca_i : in phy_ca_t;
        dq_i : in phy_dq_out_t;
        dq_o : out phy_dq_in_t
    );
end;

architecture arch of sim_phy is
begin
    dq_o <= (
        data => (others => (others => '0')),
        edc_in => (others => (others => '0')),
        edc_write => (others => (others => '0')),
        edc_read => (others => (others => '0'))
    );

    decode : entity work.decode_commands generic map (
        ASSERT_UNEXPECTED => true
    ) port map (
        clk_i => clk_i,
        ca_command_i => (ca => ca_i.ca, ca3 => ca_i.ca3),
        tick_count_o => open
    );
end;
