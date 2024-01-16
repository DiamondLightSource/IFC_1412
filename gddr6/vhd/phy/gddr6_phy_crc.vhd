-- Compute CRC for data passing over the wire to/from SGRAM

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity gddr6_phy_crc is
    port (
        clk_i : in std_ulogic;

        edc_delay_i : in unsigned(4 downto 0);

        output_enable_i : in std_ulogic;
        data_in_i : in vector_array(63 downto 0)(7 downto 0);
        dbi_n_in_i : in vector_array(7 downto 0)(7 downto 0);
        data_out_i : in vector_array(63 downto 0)(7 downto 0);
        dbi_n_out_i : in vector_array(7 downto 0)(7 downto 0);

        edc_out_o : out vector_array(7 downto 0)(7 downto 0)
    );
end;

architecture arch of gddr6_phy_crc is
    signal edc_in : vector_array(7 downto 0)(7 downto 0);
    signal edc_out : vector_array(7 downto 0)(7 downto 0);

    signal enable_delay : edc_delay_i'SUBTYPE := (others => '0');
    signal crc_delay : edc_delay_i'SUBTYPE := (others => '0');
    signal output_enable_delay : std_ulogic;
    signal edc_out_delay : vector_array(7 downto 0)(7 downto 0);

begin
    -- Separate CRC calculations for incoming and outgoing data, but only one of
    -- them will be useful.
    crc_in : entity work.gddr6_phy_crc_core port map (
        clk_i => clk_i,
        data_i => data_in_i,
        dbi_n_i => dbi_n_in_i,
        edc_o => edc_in
    );

    crc_out : entity work.gddr6_phy_crc_core port map (
        clk_i => clk_i,
        data_i => data_out_i,
        dbi_n_i => dbi_n_out_i,
        edc_o => edc_out
    );


    -- Delay output_enable and computed edc_out by configurable delay before
    -- selecting which result to deliver
    delay_enable : entity work.short_delay port map (
        clk_i => clk_i,
        delay_i => enable_delay,
        data_i(0) => output_enable_i,
        data_o(0) => output_enable_delay
    );

    gen_crc_delay : for i in 0 to 7 generate
        delay : entity work.short_delay generic map (
            WIDTH => 8
        ) port map (
            clk_i => clk_i,
            delay_i => crc_delay,
            data_i => edc_out(i),
            data_o => edc_out_delay(i)
        );
    end generate;


    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Due to an extra output delay on enable_delay it needs to be one
            -- tick ahead of the data, and upstream processing (in _map_dbi)
            -- plus the crc calculation above delays this a further two ticks.
            -- We fudge this here with an extra delay!
            crc_delay <= edc_delay_i;
            enable_delay <= edc_delay_i + 3;

            -- Select CRC data to process.  If output_enable_i is set then use
            -- outgoing data, otherwise use incoming data.
            if output_enable_delay then
                edc_out_o <= edc_out_delay;
            else
                edc_out_o <= edc_in;
            end if;
        end if;
    end process;
end;
