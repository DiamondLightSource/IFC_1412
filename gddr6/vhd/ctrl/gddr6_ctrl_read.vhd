-- Write command generation

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_command_defs.all;
use work.gddr6_ctrl_core_defs.all;
use work.gddr6_ctrl_timing_defs.all;

entity gddr6_ctrl_read is
    generic (
        -- Extra delay on incoming data
        PHY_INPUT_DELAY : natural
    );
    port (
        clk_i : in std_ulogic;

        -- AXI interface
        -- WA Write Adddress
        ra_address_i : in unsigned(24 downto 0);
        ra_count_i : in unsigned(4 downto 0);
        ra_valid_i : in std_ulogic;
        ra_ready_o : out std_ulogic := '1';
        -- WA Lookahead
        ral_address_i : in unsigned(24 downto 0);
        ral_valid_i : in std_ulogic;
        -- RD Read Data
        rd_valid_o : out std_ulogic := '0';
        rd_ok_o : out std_ulogic;
        rd_ok_valid_o : out std_ulogic := '0';

        -- Connection to core for row management and access arbitration
        request_o : out core_request_t;
        request_ready_i : in std_ulogic;
        command_sent_i : in std_ulogic;

        lookahead_o : out core_lookahead_t;

        -- EDC data
        edc_in_i : in vector_array(7 downto 0)(7 downto 0);
        edc_read_i : in vector_array(7 downto 0)(7 downto 0)
    );
end;

architecture arch of gddr6_ctrl_read is
    subtype ROW_RANGE is natural range 24 downto 11;
    subtype BANK_RANGE is natural range 10 downto 7;
    subtype COLUMN_RANGE is natural range 6 downto 0;

    signal read_request : core_request_t := IDLE_CORE_REQUEST(DIR_READ);
    signal lookahead : core_lookahead_t := IDLE_CORE_LOOKAHEAD;

    signal lookahead_new_row : std_ulogic;
    signal auto_precharge : std_ulogic;

    -- Timing signals for data and EDC
    signal data_valid : std_ulogic;
    signal last_data_valid : std_ulogic := '0';
    signal edc_valid : std_ulogic := '0';
    signal last_edc_valid : std_ulogic := '0';

    signal edc_read : vector_array(7 downto 0)(7 downto 0);

begin
    -- Only forward the lookahead if it opens a new bank
    lookahead_new_row <= to_std_ulogic(
        ral_address_i(ROW_RANGE) /= ra_address_i(ROW_RANGE) and
        ral_address_i(BANK_RANGE) /= ra_address_i(BANK_RANGE));

    -- Only generate precharge if we're reasonably confident that we're done
    -- with this row: the column address is the last column of the row, count
    -- is zero, and there isn't a lookahead on the same row.  This can still
    -- misfire, but seems a reasonable hueristic.
    auto_precharge <= to_std_ulogic(
        ra_count_i = 0 and ra_address_i(COLUMN_RANGE) = 7X"7F" and
        (ral_valid_i = '0' or lookahead_new_row = '1'));

    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Prepare the read request.  This will be transmitted on the tick
            -- we see ra_valid_i and request_ready_i.  This buffering ensures we
            -- can send a request every other tick when available.
            if ra_valid_i and (not read_request.valid or request_ready_i) then
                read_request <= (
                    direction => DIR_READ,
                    bank => ra_address_i(BANK_RANGE),
                    row => ra_address_i(ROW_RANGE),
                    command => SG_RD(
                        ra_address_i(BANK_RANGE), ra_address_i(COLUMN_RANGE),
                        auto_precharge),
                    precharge => auto_precharge,
                    extra => '0', next_extra => '0',
                    valid => '1'
                );

                -- It is simplest to only update the lookahead when there is a
                -- new read request, as the supporting calculations are valid
                lookahead <= (
                    bank => ral_address_i(BANK_RANGE),
                    row => ral_address_i(ROW_RANGE),
                    -- We need the new row open at least 2.5 bursts early, and
                    -- start asking one tick earlier
                    valid => ral_valid_i and lookahead_new_row and
                        to_std_ulogic(ra_count_i <= 3)
                );
            elsif request_ready_i then
                read_request.valid <= '0';
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
            rd_valid_o <= data_valid or last_data_valid;

            -- Align edc_read with edc_in_i
            edc_read <= edc_read_i;
            if edc_valid then
                rd_ok_o <= to_std_ulogic(edc_read = edc_in_i);
            elsif last_edc_valid then
                rd_ok_o <= rd_ok_o and to_std_ulogic(edc_read = edc_in_i);
            end if;
            rd_ok_valid_o <= last_edc_valid;
        end if;
    end process;

    -- Use incoming acknowledgement of send the command to trigger data
    -- transfer at the appropriate time
    delay_rd_valid : entity work.fixed_delay generic map (
        DELAY => RLmrs + PHY_INPUT_DELAY
    ) port map (
        clk_i => clk_i,
        data_i(0) => command_sent_i,
        data_o(0) => data_valid
    );

    ra_ready_o <= not read_request.valid or request_ready_i;
    request_o <= read_request;
    lookahead_o <= lookahead;
end;
