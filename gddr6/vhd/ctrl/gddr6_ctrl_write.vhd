-- Write command generation

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_ctrl_defs.all;

entity gddr6_ctrl_write is
    port (
        clk_i : in std_ulogic;

        -- WA Write Adddress
        wa_address_i : in unsigned(24 downto 0);
        wa_byte_mask_i : in std_ulogic_vector(127 downto 0);
        wa_count_i : in unsigned(4 downto 0);
        wa_valid_i : in std_ulogic;
        wa_ready_o : out std_ulogic;
        -- WA Lookahead
        wal_address_i : in unsigned(24 downto 0);
        wal_valid_i : in std_ulogic;
        -- WD Write Data
        wd_data_i : in vector_array(63 downto 0)(7 downto 0);
        wd_hold_o : out std_ulogic;
        wd_ready_o : out std_ulogic;
        -- WR Write Response
        wr_ok_o : out std_ulogic;
        wr_ok_valid_o : out std_ulogic;

        -- Connection to core for row management and access arbitration
        request_o : out core_request_t;
        request_ready_i : in std_ulogic;
        lookahead_o : out core_lookahead_t;
        write_byte_mask_o : out std_ulogic;

        -- EDC data
        edc_in_i : in vector_array(7 downto 0)(7 downto 0);
        edc_write_i : in vector_array(7 downto 0)(7 downto 0)
    );
end;

architecture arch of gddr6_ctrl_write is
    -- Types used to decode byte mask
    type byte_mask_t is (
        BYTE_MASK_NOP,      -- No bytes set, do not write to this channel
        BYTE_MASK_WOM,      -- All bytes sent, can use WOM command to write
        BYTE_MASK_WDM,      -- Byte pattern consistent with double mask MDM
        BYTE_MASK_WSM       -- Must use WSM
    );

    function decode_byte_mask(
        mask : std_ulogic_vector(31 downto 0)) return byte_mask_t
    is
        variable even_bits : std_ulogic_vector(15 downto 0);
        variable odd_bits : std_ulogic_vector(15 downto 0);
    begin
        for i in 0 to 15 loop
            even_bits(i) := mask(2*i);
            odd_bits(i)  := mask(2*i + 1);
        end loop;

        if vector_or(mask) = '0' then
            return BYTE_MASK_NOP;
        elsif vector_and(mask) = '1' then
            return BYTE_MASK_WOM;
        elsif even_bits = odd_bits then
            return BYTE_MASK_WDM;
        else
            return BYTE_MASK_WSM;
        end if;
    end;

begin

    This is going to be half an almost exact copy of read and half a lot of work
    on byte mask management


end;
