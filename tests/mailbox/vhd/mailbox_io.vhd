-- IO mappings

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity mailbox_io is
    port (
        clk_i : in std_ulogic;

        -- External pins
        scl_i : in std_ulogic;
        sda_io : inout std_logic;

        scl_o : out std_ulogic;
        sda_o : out std_ulogic;
        sda_i : in std_ulogic
    );
end;

architecture arch of mailbox_io is
    signal sda_in : std_ulogic;
    signal scl_in : std_ulogic;

begin
    ibuf_scl : IBUF port map (
        I => scl_i,
        O => scl_in
    );

    iobuf_sda : IOBUF port map (
        T => sda_i,
        I => '0',
        O => sda_in,
        IO => sda_io
    );


    sync_scl : entity work.sync_bit generic map (
        INITIAL => '1'
    ) port map (
        clk_i => clk_i,
        bit_i => scl_in,
        bit_o => scl_o
    );

    sync_sda : entity work.sync_bit generic map (
        INITIAL => '1'
    ) port map (
        clk_i => clk_i,
        bit_i => sda_in,
        bit_o => sda_o
    );
end;
