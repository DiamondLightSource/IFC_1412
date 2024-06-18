-- AXI Write Response B interface

-- All three interfaces update at most every other tick so simple ping-pong
-- handshaking and flow control is adequate.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_axi_defs.all;

entity gddr6_axi_write_response is
    port (
        clk_i : in std_ulogic;

        -- Response control from AXI WA
        response_i : in burst_response_t;
        response_ready_o : out std_ulogic := '0';

        -- Write status from control
        data_ok_i : in std_ulogic;
        data_ok_valid_i : in std_ulogic;
        data_ok_ready_o : out std_ulogic := '0';

        -- AXI B interface
        axi_response_o : out axi_write_response_t := IDLE_AXI_WRITE_RESPONSE;
        axi_ready_i : in std_ulogic
    );
end;

architecture arch of gddr6_axi_write_response is
    signal response : burst_response_t := IDLE_BURST_RESPONSE;
    signal data_ok : std_ulogic;

begin
    process (clk_i)
        -- Advance the response state machine
        procedure advance_response(response_ready : std_ulogic) is
            variable advance_count : std_ulogic;
        begin
            advance_count :=
                response.valid and not response.invalid_burst and
                response.count ?> 0;
            if response_ready and advance_count then
                -- Count off and accumulate data points until all received
                response.count <= response.count - 1;
                data_ok <= data_ok and data_ok_i;
                response_ready_o <= '0';
            elsif response_ready or not response.valid then
                -- Load a new response if available
                response <= response_i;
                data_ok <= '1';
                response_ready_o <= response_i.valid;
            else
                response_ready_o <= '0';
            end if;
        end;


        procedure advance_axi(axi_valid : std_ulogic) is
            impure function resp return std_ulogic_vector is
            begin
                if response.invalid_burst or not (data_ok and data_ok_i) then
                    return "10";        -- SLVERR
                else
                    return "00";        -- OKAY
                end if;
            end;
        begin
            if axi_ready_i or not axi_response_o.valid then
                axi_response_o <= (
                    id => response.id,
                    resp => resp,
                    valid => axi_valid
                );
            end if;
        end;

        variable axi_ready : std_ulogic;
        variable axi_valid : std_ulogic;
        variable data_ready : std_ulogic;
        variable response_ready : std_ulogic;

    begin
        if rising_edge(clk_i) then
            axi_ready := axi_ready_i or not axi_response_o.valid;

            -- Data and 
            if response.valid then
                if response.invalid_burst then
                    -- For invalid bursts we can respond as soon as AXI is ready
                    data_ready := '0';
                    axi_valid := '1';
                    response_ready := axi_ready;
                elsif response.count > 0 then
                    -- When counting data need to consume data with no response
                    data_ready := '1';
                    axi_valid := '0';
                    response_ready := data_ok_valid_i;
                else
                    -- For the final stage we consume data and AXI together
                    data_ready := axi_ready;
                    axi_valid := data_ok_valid_i;
                    response_ready := axi_ready and data_ok_valid_i;
                end if;
            else
                data_ready := '0';
                axi_valid := '0';
                response_ready := '0';
            end if;

            advance_axi(axi_valid);
            advance_response(response_ready);
            -- Acknowledge data on receipt
            data_ok_ready_o <= data_ready and data_ok_valid_i;
        end if;
    end process;
end;
