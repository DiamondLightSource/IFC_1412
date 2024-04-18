-- Lookahead generation

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_defs.all;

entity gddr6_ctrl_lookahead is
    port (
        clk_i : in std_ulogic;

        -- Incoming lookahead requests.  Only valid when corresponding request
        -- stream is busy enough
        -- RA Lookahead
        ral_address_i : in unsigned(24 downto 0);
        ral_count_i : in unsigned(4 downto 0);
        ral_valid_i : in std_ulogic;
        -- WA Lookahead
        wal_address_i : in unsigned(24 downto 0);
        wal_count_i : in unsigned(4 downto 0);
        wal_valid_i : in std_ulogic;

        -- Banks status
        status_i : in banks_status_t;
        -- Only select lookahead in the currently active direction
        direction_i : in direction_t;

        -- Lookahead open requests
        lookahead_o : out bank_open_t := IDLE_OPEN_REQUEST
    );
end;

architecture arch of gddr6_ctrl_lookahead is
    -- Slightly arbitrary decision point for enabling lookahead.  Read lookahead
    -- requires about three more commands lookahead than write.
    constant WRITE_LOOKAHEAD_COUNT : natural := 5;
    constant READ_LOOKAHEAD_COUNT : natural := WRITE_LOOKAHEAD_COUNT + 3;

    signal row : unsigned(13 downto 0);
    signal bank : unsigned(3 downto 0);
    signal count_ok : std_ulogic := '0';
    signal valid : std_ulogic := '0';

begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Select incoming lookahead request according to the current data
            -- direction.  Note that the count must be greater than zero to
            -- ensure that the lookahead goes invalid between requests.
            case direction_i is
                when DIR_READ =>
                    bank <= ral_address_i(BANK_RANGE);
                    row <= ral_address_i(ROW_RANGE);
                    count_ok <= to_std_ulogic(
                        0 < ral_count_i and ral_count_i < READ_LOOKAHEAD_COUNT);
                    valid <= ral_valid_i;
                when DIR_WRITE =>
                    bank <= wal_address_i(BANK_RANGE);
                    row <= wal_address_i(ROW_RANGE);
                    count_ok <= to_std_ulogic(
                        0 < wal_count_i and
                        wal_count_i < WRITE_LOOKAHEAD_COUNT);
                    valid <= wal_valid_i;
            end case;

            -- Emit selected lookahead, but only mark as valid if the counter is
            -- in range.  Also avoid generating an open request on a bank marked
            -- as young.
            lookahead_o <= (
                bank => bank,
                row => row,
                valid => valid and count_ok and
                    not status_i.young(to_integer(bank))
            );
        end if;
    end process;
end;
