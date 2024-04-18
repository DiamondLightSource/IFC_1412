-- Read command generation

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_command_defs.all;
use work.gddr6_ctrl_defs.all;

entity gddr6_ctrl_read is
    port (
        clk_i : in std_ulogic;

        -- AXI interface
        axi_address_i : in unsigned(24 downto 0);
        axi_valid_i : in std_ulogic;
        axi_ready_o : out std_ulogic := '1';

        -- Outgoing read request
        read_request_o : out core_request_t := IDLE_CORE_REQUEST(DIR_READ);
        read_ready_i : in std_ulogic
    );
end;

architecture arch of gddr6_ctrl_read is
    -- Decode of read address
    signal row : unsigned(13 downto 0);
    signal bank : unsigned(3 downto 0);
    signal column : unsigned(6 downto 0);

    -- Placeholder for auto precharge, not actually implemented.  Complex to
    -- get right, very low return, doesn't seem to earn its keep.
    signal auto_precharge : std_ulogic := '0';

begin
    bank <= axi_address_i(BANK_RANGE);
    row <= axi_address_i(ROW_RANGE);
    column <= axi_address_i(COLUMN_RANGE);

    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Simple ping-pong one stage buffering
            if axi_valid_i and axi_ready_o then
                read_request_o <= (
                    direction => DIR_READ,
                    write_advance => '0',
                    bank => bank,
                    row => row,
                    command => SG_RD(bank, column, auto_precharge),
                    auto_precharge => auto_precharge,
                    extra => '0', next_extra => '0',
                    valid => '1'
                );
                axi_ready_o <= '0';
            elsif read_ready_i and read_request_o.valid then
                read_request_o.valid <= '0';
                axi_ready_o <= '1';
            end if;
        end if;
    end process;
end;
