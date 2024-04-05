-- Data handling for read and write commands

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.gddr6_ctrl_core_defs.all;
use work.gddr6_ctrl_timing_defs.all;

entity gddr6_ctrl_data is
    port (
        clk_i : in std_ulogic;

        -- Data completion events
        request_completion_i : in request_completion_t;

        -- Output enable
        output_enable_o : out std_ulogic;

        -- Data to and from PHY
        phy_data_i : in vector_array(63 downto 0)(7 downto 0);
        phy_data_o : out vector_array(63 downto 0)(7 downto 0);
        -- EDC data
        edc_in_i : in vector_array(7 downto 0)(7 downto 0);
        edc_read_i : in vector_array(7 downto 0)(7 downto 0);
        edc_write_i : in vector_array(7 downto 0)(7 downto 0);

        -- AXI connection
        -- RD
        axi_rd_data_o : out vector_array(0 to 3)(127 downto 0);
        axi_rd_valid_o : out std_ulogic;
        axi_rd_ok_o : out std_ulogic;
        axi_rd_ok_valid_o : out std_ulogic;
        -- WR
        axi_wr_data_i : in vector_array(0 to 3)(127 downto 0);
        axi_wr_ready_o : out std_ulogic;
        axi_wr_ok_o : out std_ulogic;
        axi_wr_ok_valid_o : out std_ulogic
    );
end;

architecture arch of gddr6_ctrl_data is
    -- Extra delay on incoming data
    constant PHY_INPUT_DELAY : natural := ???;

    -- Timing signals for data and EDC
    signal data_valid : std_ulogic;
    signal last_data_valid : std_ulogic := '0';
    signal edc_valid : std_ulogic := '0';
    signal last_edc_valid : std_ulogic := '0';

    signal edc_read : vector_array(7 downto 0)(7 downto 0);

    signal rd_valid_out : std_ulogic := '0';
    signal rd_ok_out : std_ulogic := '0';
    signal rd_ok_valid_out : std_ulogic := '0';

begin
    -- Map between PHY and AXI data formats.  PHY data is organised by pin and
    -- WCK tick, AXI data is flattened but organised into channels.
    gen_channel : for ch in 0 to 3 generate
        gen_lane : for lane in 0 to 15 generate
            constant wire : natural := 4 * ch + lane;
        begin
            gen_beat : for beat in 0 to 7 generate
                constant bit : natural := 16 * beat + lane;
            begin
                axi_rd_data_o(ch)(bit) <= phy_data_i(wire)(beat);
                phy_data_o(wire)(beat) <= axi_wr_data_i(ch)(bit);
            end generate;
        end generate;
    end generate;


    process (clk_i) begin
        if rising_edge(clk_i) then
            -- We have three values that need to be reconciled for a particular
            -- read: data in, edc_read_i computed from data in, and edc_in_i
            -- directly from SG, and we need to align the two EDC values to
            -- validate the transfer.
            --  edc_read_i arrives at data_valid_delay
            --  edc_in_i arrives one tick later

            last_data_valid <= data_valid;
            edc_valid <= last_data_valid;
            last_edc_valid <= edc_valid;

            -- Data is written over two ticks
            rd_valid_out <= data_valid or last_data_valid;

            -- Align edc_read with edc_in_i
            edc_read <= edc_read_i;
            if edc_valid then
                rd_ok_out <= to_std_ulogic(edc_read = edc_in_i);
            elsif last_edc_valid then
                rd_ok_out <= rd_ok_out and to_std_ulogic(edc_read = edc_in_i);
            end if;
            rd_ok_valid_out <= last_edc_valid;
        end if;
    end process;


    -- Use incoming acknowledgement of send the command to trigger data
    -- transfer at the appropriate time
    delay_rd_valid : entity work.fixed_delay generic map (
        DELAY => RLmrs + PHY_INPUT_DELAY
    ) port map (
        clk_i => clk_i,
        data_i(0) => read_sent_i,
        data_o(0) => data_valid
    );

    axi_response_o <= (
        ra_ready => ra_ready_out,
        rd_valid => rd_valid_out,
        rd_ok => rd_ok_out,
        rd_ok_valid => rd_ok_valid_out
    );
end;
