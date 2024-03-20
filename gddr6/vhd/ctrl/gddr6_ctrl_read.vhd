-- Write command generation

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_command_defs.all;
use work.gddr6_ctrl_core_defs.all;
use work.gddr6_ctrl_timing_defs.all;
use work.gddr6_defs.all;

entity gddr6_ctrl_read is
    generic (
        -- Extra delay on incoming data
        PHY_INPUT_DELAY : natural
    );
    port (
        clk_i : in std_ulogic;

        -- AXI interface
        axi_request_i : in axi_read_request_t;
        axi_response_o : out axi_read_response_t;

        -- Outgoing read request with send acknowledgement
        read_request_o : out core_request_t := IDLE_CORE_REQUEST(DIR_READ);
        read_ready_i : in std_ulogic;
        read_sent_i : in std_ulogic;
        -- Read lookahead
        read_lookahead_o : out bank_open_t := IDLE_OPEN_REQUEST;

        -- EDC data
        edc_in_i : in vector_array(7 downto 0)(7 downto 0);
        edc_read_i : in vector_array(7 downto 0)(7 downto 0)
    );
end;

architecture arch of gddr6_ctrl_read is
    -- Slightly arbitrary decision point for enabling lookahead
    -- We need the new row open at least 2.5 bursts early, and
    -- start asking one tick earlier
    constant LOOKAHEAD_COUNT : natural := 5;

    signal lookahead_new_bank : std_ulogic;
    signal auto_precharge : std_ulogic;

    -- Timing signals for data and EDC
    signal data_valid : std_ulogic;
    signal last_data_valid : std_ulogic := '0';
    signal edc_valid : std_ulogic := '0';
    signal last_edc_valid : std_ulogic := '0';

    signal edc_read : vector_array(7 downto 0)(7 downto 0);

    -- AXI response
    signal ra_ready_out : std_ulogic := '1';
    signal rd_valid_out : std_ulogic := '0';
    signal rd_ok_out : std_ulogic := '0';
    signal rd_ok_valid_out : std_ulogic := '0';

begin
    -- Only forward the lookahead if it opens a new bank
    lookahead_new_bank <= to_std_ulogic(
        axi_request_i.ral_address(BANK_RANGE) /=
        axi_request_i.ra_address(BANK_RANGE));

    -- Only generate precharge if we're reasonably confident that we're done
    -- with this row: the column address is the last column of the row, count
    -- is zero, and there isn't a lookahead on the same row.  This can still
    -- misfire, but seems a reasonable hueristic.
    auto_precharge <= to_std_ulogic(
        axi_request_i.ra_count = 0 and
        axi_request_i.ra_address(COLUMN_RANGE) = 7X"7F") and
        (not axi_request_i.ral_valid or lookahead_new_bank);

    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Prepare the read request.  This will be transmitted on the tick
            -- we see ra_valid and read_ready_i.  This buffering ensures
            -- we can send a request every other tick when available.
            if axi_request_i.ra_valid and axi_response_o.ra_ready then
                -- Receive incoming
                read_request_o <= (
                    direction => DIR_READ,
                    bank => axi_request_i.ra_address(BANK_RANGE),
                    row => axi_request_i.ra_address(ROW_RANGE),
                    command => SG_RD(
                        axi_request_i.ra_address(BANK_RANGE),
                        axi_request_i.ra_address(COLUMN_RANGE),
                        auto_precharge),
                    precharge => auto_precharge,
                    extra => '0', next_extra => '0',
                    valid => '1'
                );
                ra_ready_out <= '0';

                -- Only emit the lookahead if it's opening a new row
                read_lookahead_o <= (
                    bank => axi_request_i.ral_address(BANK_RANGE),
                    row => axi_request_i.ral_address(ROW_RANGE),
                    -- It is important that lookahead go invalid between valid
                    -- requests so that new requests can be identified
                    valid =>
                        axi_request_i.ral_valid and lookahead_new_bank and
                        to_std_ulogic(
                            0 < axi_request_i.ra_count and
                            axi_request_i.ra_count < LOOKAHEAD_COUNT)
                );
            elsif read_ready_i and read_request_o.valid then
                -- Transmit outgoing
                read_request_o.valid <= '0';
                read_lookahead_o.valid <= '0';
                ra_ready_out <= '1';
            end if;

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
