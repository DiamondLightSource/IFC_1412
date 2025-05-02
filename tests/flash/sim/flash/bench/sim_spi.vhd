-- Simple SPI simulation

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sim_support;

entity sim_spi is
    generic (
        NAME : string;
        READ_DELAY : time
    );
    port (
        clk_i : in std_ulogic;
        cs_i : in std_ulogic;
        mosi_i : in std_ulogic;
        miso_o : out std_ulogic := 'Z'
    );
end;

architecture arch of sim_spi is
    procedure write(message : string := "") is
    begin
        sim_support.write(NAME & " " & message, true);
    end;

begin
    process
        variable count : integer := 0;
        variable byte : std_ulogic_vector(7 downto 0);
    begin
        wait until falling_edge(cs_i);
        write("CS low");

        loop
            wait until rising_edge(clk_i) or rising_edge(cs_i);
            if cs_i then
                write("CS high");
                exit;
            else
                byte := byte(6 downto 0) & mosi_i;
                count := (count + 1) mod 8;
                if count = 0 then
                    write(to_hstring(byte));
                end if;
            end if;
        end loop;
    end process;

    miso_o <= transport mosi_i after READ_DELAY;
end;
