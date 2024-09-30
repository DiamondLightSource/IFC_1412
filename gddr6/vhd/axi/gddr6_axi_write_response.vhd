-- AXI Write Response B interface

-- All three interfaces update at most every other tick so simple ping-pong
-- handshaking and flow control is adequate.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.flow_control.all;

use work.gddr6_defs.all;
use work.gddr6_axi_defs.all;

entity gddr6_axi_write_response is
    port (
        clk_i : in std_ulogic;

        -- Response control from AXI WA
        response_i : in burst_response_t;
        response_ready_o : out std_ulogic := '1';

        -- Write status from control
        data_ok_i : in std_ulogic;
        data_ok_valid_i : in std_ulogic;
        data_ok_ready_o : out std_ulogic := '1';

        -- AXI B interface
        axi_response_o : out axi_write_response_t := IDLE_AXI_WRITE_RESPONSE;
        axi_ready_i : in std_ulogic;

        stats_crc_error_o : out std_ulogic := '0';
        stats_transfer_o : out std_ulogic := '0'
    );
end;

architecture arch of gddr6_axi_write_response is
    signal response : burst_response_t := IDLE_BURST_RESPONSE;
    signal data_ok : std_ulogic;
    signal data_ok_valid : std_ulogic := '0';
    signal burst_ok : std_ulogic;
    signal burst_ok_valid : std_ulogic := '0';

begin
    process (clk_i)
        procedure compute_ready_valid(
            variable response_ready : out std_ulogic;
            variable axi_valid : out std_ulogic)
        is
            variable axi_ready : std_ulogic;
        begin
            axi_ready := axi_ready_i or not axi_response_o.valid;
            if response.valid then
                if response.invalid_burst then
                    -- For an invalid burst there is no returned status to
                    -- check so we can advance our state immediately
                    response_ready := axi_ready;
                    axi_valid := '1';
                elsif not burst_ok_valid then
                    -- Need to give the response engine a valid data point
                    response_ready := data_ok_valid;
                    axi_valid := '0';
                elsif response.count > 0 then
                    -- Need valid data to advance the response
                    response_ready := data_ok_valid;
                    axi_valid := '0';
                else
                    -- At state end hand over response to AXI
                    response_ready := axi_ready;
                    axi_valid := '1';
                end if;
            else
                -- Load a fresh response if available
                response_ready := '1';      -- Actually ignored in this case
                axi_valid := '0';
            end if;
        end;


        -- Advance the response control.  If we are processing a valid burst we
        -- need to count down responses, otherwise a new response can be loaded.
        procedure advance_response(
            response_ready : std_ulogic;
            variable data_ok_ready : out std_ulogic)
        is
            variable load_new_response : std_ulogic;
            variable load_value : std_ulogic;
        begin
            load_new_response :=
                not response.valid or response.invalid_burst or
                (response.count ?= 0 and burst_ok_valid);
            advance_state_machine_and_ping_pong(
                response_i.valid, response_ready, load_new_response,
                response.valid, response_ready_o,
                load_value);

            data_ok_ready := '0';
            if load_value then
                if load_new_response then
                    -- Load fresh state.  Will need to load data as a separate
                    -- step if required (not an invalid burst)
                    response <= response_i;
                    if response_i.invalid_burst then
                        burst_ok <= '0';
                    else
                        -- If data is not available when loading the new state
                        -- mark the burst as ok so far, but ensure the ok state
                        -- is not yet marked as valid
                        burst_ok <= data_ok or not data_ok_valid;
                        burst_ok_valid <= data_ok_valid;
                        data_ok_ready := '1';
                    end if;
                elsif data_ok_valid then
                    -- If data valid we can consume it and update the state,
                    -- otherwise stand still
                    if burst_ok_valid then
                        response.count <= response.count - 1;
                    end if;
                    burst_ok <= burst_ok and data_ok;
                    burst_ok_valid <= '1';
                    data_ok_ready := '1';
                end if;
            end if;
        end;


        procedure advance_data_ok(data_ok_ready : std_ulogic)
        is
            variable load_value : std_ulogic;
        begin
            advance_ping_pong_buffer(
                data_ok_valid_i, data_ok_ready,
                data_ok_valid, data_ok_ready_o, load_value);
            if load_value then
                data_ok <= data_ok_i;
            end if;
            stats_crc_error_o <= load_value and not data_ok_i;
        end;


        procedure advance_axi(axi_valid : std_ulogic)
        is
            variable resp : std_ulogic_vector(1 downto 0);
        begin
            resp := "00" when burst_ok else "10";   -- OKAY or SLVERR
            if axi_ready_i or not axi_response_o.valid then
                axi_response_o <= (
                    id => response.id,
                    resp => resp,
                    valid => axi_valid
                );
            end if;
            stats_transfer_o <=
                (axi_ready_i or not axi_response_o.valid) and axi_valid;
        end;


        variable response_ready : std_ulogic;
        variable data_ok_ready : std_ulogic;
        variable axi_valid : std_ulogic;

    begin
        if rising_edge(clk_i) then
            compute_ready_valid(response_ready, axi_valid);
            advance_response(response_ready, data_ok_ready);
            advance_data_ok(data_ok_ready);
            advance_axi(axi_valid);
        end if;
    end process;
end;
