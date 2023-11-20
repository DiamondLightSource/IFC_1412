-- Compute CRC for data passing over the wire to/from SGRAM

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity gddr6_phy_crc is
    port (
        clk_i : in std_ulogic;

        capture_dbi_i : in std_ulogic;
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
    signal edc_delay_in : edc_delay_i'SUBTYPE := (others => '0');
    signal output_enable_delay : std_ulogic;
    signal data_out_delay : vector_array(63 downto 0)(7 downto 0);
    signal dbi_n_out_delay : vector_array(7 downto 0)(7 downto 0);

    signal selected_data : vector_array(63 downto 0)(7 downto 0);
    signal selected_dbi_n : vector_array(7 downto 0)(7 downto 0);
    signal edc_out : vector_array(7 downto 0)(7 downto 0);

begin
    -- Programmable delays for output enable and outgoing data so that we only
    -- need one instance of the CRC.
    delay_enable : entity work.short_delay generic map (
        REGISTER_OUTPUT => true
    ) port map (
        clk_i => clk_i,
        delay_i => edc_delay_in,
        data_i(0) => output_enable_i,
        data_o(0) => output_enable_delay
    );

    gen_data_delay : for i in 0 to 63 generate
        delay : entity work.short_delay generic map (
            WIDTH => 8,
            REGISTER_OUTPUT => false
        ) port map (
            clk_i => clk_i,
            delay_i => edc_delay_in,
            data_i => data_out_i(i),
            data_o => data_out_delay(i)
        );
    end generate;

    gen_dbi_delay : for i in 0 to 7 generate
        delay : entity work.short_delay generic map (
            WIDTH => 8,
            REGISTER_OUTPUT => false
        ) port map (
            clk_i => clk_i,
            delay_i => edc_delay_in,
            data_i => dbi_n_out_i(i),
            data_o => dbi_n_out_delay(i)
        );
    end generate;


    process (clk_i) begin
        if rising_edge(clk_i) then
            edc_delay_in <= edc_delay_i;

            -- Select CRC data to process.  If output_enable_i is set then use
            -- outgoing data, otherwise use incoming data.
            if output_enable_delay then
                selected_data <= data_out_delay;
                selected_dbi_n <= dbi_n_out_delay;
            else
                selected_data <= data_in_i;
                selected_dbi_n <= dbi_n_in_i;
            end if;

            if capture_dbi_i then
                edc_out_o <= dbi_n_in_i;
            else
                edc_out_o <= edc_out;
            end if;
        end if;
    end process;


    crc : entity work.gddr6_phy_crc_core port map (
        clk_i => clk_i,
        data_i => selected_data,
        dbi_n_i => selected_dbi_n,
        edc_o => edc_out
    );
end;
