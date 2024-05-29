-- AXI RA/WA stream interface

-- Decodes incoming read or write request and generates a decoded burst command
-- together with an address for the SG transfers

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_axi_defs.all;

entity gddr6_axi_address is
    port (
        clk_i : in std_ulogic;

        -- AXI RA/WA interface
        axi_address_i : in axi_address_t;
        axi_ready_o : out std_ulogic := '0';

        -- FIFO to AXI R/W data interface
        fifo_command_o : out burst_command_t := IDLE_BURST_COMMAND;
        fifo_ready_i : in std_ulogic;

        -- Address request to controller with number of SG bursts to transfer
        -- for this request
        ctrl_address_o : out address_t := IDLE_ADDRESS;
        ctrl_ready_i : in std_ulogic
    );
end;

architecture arch of gddr6_axi_address is
    -- Computes the offset of the last AXI transfer relative to the initial SG
    -- burst offset: bits 11:7 will be the SG count, just so long as 1/ size is
    -- not 7 and 2/ bits 14:12 are zero.
    function last_offset(address : axi_address_t) return unsigned is
    begin
        return
            (8X"00" & address.addr(6 downto 0)) +
            shift_left(resize(address.len, 15), to_integer(address.size));
    end;

    -- Check that the request is valid: we enforce AWBURST = INCR and ARSIZE
    -- is no larger than our bus size.  We don't bother to check the burst
    -- doesn't cross a page boundary, we can still process it but the data
    -- returned might be wrong.  However, we also need to check that the SG
    -- burst count implicit in the outgoing burst command doesn't overflow the
    -- explict 5-bit count.
    function valid_request(address : axi_address_t) return std_ulogic is
    begin
        return to_std_ulogic(
            address.burst = "01" and address.size /= 7 and
            last_offset(address)(14 downto 12) = "000");
    end;

    function command(address : axi_address_t) return burst_command_t
    is
        variable step : unsigned(6 downto 0);
    begin
        step := shift_left(to_unsigned(1, 7), to_integer(address.size));
        return (
            id => address.id,
            count => address.len,
            -- Ensure start offset is a multiple of step size
            offset => address.addr(6 downto 0) and (step - 1),
            step => step,
            invalid_burst => not valid_request(address),
            valid => '1'
        );
    end;

    function address(address : axi_address_t) return address_t is
    begin
        return (
            address => address.addr(31 downto 7),
            count => last_offset(address)(11 downto 7),
            valid => '1'
        );
    end;

begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            if axi_address_i.valid and axi_ready_o then
                -- Process incoming request
                fifo_command_o <= command(axi_address_i);
                if valid_request(axi_address_i) then
                    ctrl_address_o <= address(axi_address_i);
                end if;
                axi_ready_o <= '0';
            else
                -- Clear each command as it is accepted
                if fifo_ready_i then
                    fifo_command_o.valid <= '0';
                end if;
                if ctrl_ready_i then
                    ctrl_address_o.valid <= '0';
                end if;
                -- Accept a new command once all outstanding commands are
                -- resolved
                axi_ready_o <=
                    (fifo_ready_i or not fifo_command_o.valid) and
                    (ctrl_ready_i or not ctrl_address_o.valid);
            end if;
        end if;
    end process;
end;
