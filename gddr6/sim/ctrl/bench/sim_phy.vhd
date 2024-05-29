-- Simple simulation of memory response

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_ctrl_defs.all;
use work.gddr6_ctrl_command_defs.all;

entity sim_phy is
    port (
        clk_i : in std_ulogic;

        phy_ca_i : in phy_ca_t;
        phy_dq_i : in phy_dq_out_t;
        phy_dq_o : out phy_dq_in_t
    );
end;

architecture arch of sim_phy is
    signal data_out : vector_array(63 downto 0)(7 downto 0);
    signal edc_in : vector_array(7 downto 0)(7 downto 0);
    signal edc_write : vector_array(7 downto 0)(7 downto 0);
    signal edc_read : vector_array(7 downto 0)(7 downto 0);

begin
    phy_dq_o <= (
        data => (others => (others => 'U')),
        edc_in => (others => (others => 'U')),
        edc_write => edc_write,
        edc_read => (others => (others => 'U'))
    );

    edc_write_inst : entity work.gddr6_phy_crc port map (
        clk_i => clk_i,
        data_i => data_out,
        dbi_n_i => (others => (others => '1')),
        edc_o => edc_write
    );

    process (clk_i) begin
        if rising_edge(clk_i) then
            data_out <= phy_dq_i.data;
        end if;
    end process;
end;
