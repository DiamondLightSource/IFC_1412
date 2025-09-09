-- Simulation of core memory

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

use work.gddr6_defs.all;

use work.sim_phy_defs.all;

entity sim_phy_memory is
    port (
        clk_i : in std_ulogic;

        read_address_i : in sg_address_t;
        read_strobe_i : in std_ulogic;
        read_data_o : out phy_data_t;

        write_address_i : in sg_address_t;
        write_mask_i : in sg_write_mask_t;
        write_strobe_i : in std_ulogic;
        write_data_i : in phy_data_t
    );
end;

architecture arch of sim_phy_memory is
    -- A single SG burst is structured as 4 channels of 16 lanes each, where
    -- each lane contains 16 bits of data.
    subtype LANES_RANGE is natural range 63 downto 0;
    subtype TICKS_RANGE is natural range 15 downto 0;
    type memory_array_t is
        array(BANK_RANGE, ROW_RANGE, COLUMN_RANGE, LANES_RANGE) of
            std_ulogic_vector(TICKS_RANGE);
    signal sg_memory : memory_array_t;


    function read_memory(
        sg_memory : memory_array_t; address : sg_address_t) return phy_data_t
    is
        variable result : phy_data_t;
        subtype SLICE is natural
            range 8 * address.stage + 7 downto 8 * address.stage;
    begin
        for lane in LANES_RANGE loop
            result(lane) := sg_memory(
                address.bank, address.row, address.column, lane)(SLICE);
        end loop;
        return result;
    end;

    -- Writes to memory respecting the odd and even mask and channel enables.
    -- The pattern of writes is derived from the documentation for MSM
    procedure write_memory(
        signal sg_memory : out memory_array_t;
        address : sg_address_t;
        mask : sg_write_mask_t;
        data : phy_data_t)
    is
        -- Writes the byte for the selected channel and tick
        procedure write_byte(
            channel : natural; byte : natural;
            tick_in : natural; tick_out : natural)
        is
            variable lane : natural;
        begin
            for b in 0 to 7 loop
                lane := 16 * channel + 8 * byte + b;
                sg_memory(
                    address.bank, address.row, address.column, lane)(tick_out)
                    <= data(lane)(tick_in);
            end loop;
        end;

        variable tick_out : natural;

    begin
        for channel in 0 to 3 loop
            if mask.enables(channel) then
                for tick_in in 0 to 7 loop
                    tick_out := 8 * address.stage + tick_in;
                    if mask.even_mask(tick_out) then
                        write_byte(channel, 0, tick_in, tick_out);
                    end if;
                    if mask.odd_mask(tick_out) then
                        write_byte(channel, 1, tick_in, tick_out);
                    end if;
                end loop;
            end if;
        end loop;
    end;


begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            if write_strobe_i then
                write_memory(sg_memory,
                    write_address_i, write_mask_i, write_data_i);
            end if;

            if read_strobe_i then
                read_data_o <= read_memory(sg_memory, read_address_i);
            else
                read_data_o <= (others => (others => 'U'));
            end if;
        end if;
    end process;
end;
