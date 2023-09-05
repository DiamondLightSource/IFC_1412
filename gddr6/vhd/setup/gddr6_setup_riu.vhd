-- Mapping RIU control register to RIU interface

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.gddr6_register_defines.all;

entity gddr6_setup_riu is
    port (
        reg_clk_i : in std_ulogic;
        riu_clk_i : in std_ulogic;
        riu_clk_ok_i : in std_ulogic;

        -- Register interface
        write_strobe_i : in std_ulogic;
        write_data_i : in reg_data_t;
        write_ack_o : out std_ulogic;
        read_strobe_i : in std_ulogic;
        read_data_o : out reg_data_t;
        read_ack_o : out std_ulogic;

        -- RIU interface on riu_clk_i
        riu_addr_o : out unsigned(9 downto 0);
        riu_wr_data_o : out std_ulogic_vector(15 downto 0);
        riu_rd_data_i : in std_ulogic_vector(15 downto 0);
        riu_wr_en_o : out std_ulogic;
        riu_strobe_o : out std_ulogic;
        riu_ack_i : in std_ulogic;
        riu_error_i : in std_ulogic;
        riu_vtc_handshake_o : out std_ulogic
    );
end;

architecture arch of gddr6_setup_riu is
    -- Register interface on RIU clock
    signal write_strobe : std_ulogic;
    signal write_data : reg_data_t;
    signal write_ack : std_ulogic;
    signal read_strobe : std_ulogic;
    signal read_data : reg_data_t;
    signal read_ack : std_ulogic;

begin
    -- Bring entire register interface onto RIU clock
    cc : entity work.register_cc port map (
        clk_in_i => reg_clk_i,
        write_data_i => write_data_i,
        write_strobe_i => write_strobe_i,
        write_ack_o => write_ack_o,
        read_data_o => read_data_o,
        read_strobe_i => read_strobe_i,
        read_ack_o => read_ack_o,

        clk_out_i => riu_clk_i,
        clk_out_ok_i => riu_clk_ok_i,
        write_data_o => write_data,
        write_strobe_o => write_strobe,
        write_ack_i => write_ack,
        read_data_i => read_data,
        read_strobe_o => read_strobe,
        read_ack_i => read_ack
    );

    riu_strobe_o <= write_strobe;
    write_ack <= riu_ack_i;
    read_ack <= '1';

    riu_addr_o <= unsigned(write_data(GDDR6_RIU_ADDRESS_BITS));
    riu_wr_data_o <= write_data(GDDR6_RIU_DATA_BITS);
    riu_wr_en_o <= write_data(GDDR6_RIU_WRITE_BIT);
    riu_vtc_handshake_o <= write_data(GDDR6_RIU_VTC_BIT);

    process (riu_clk_i) begin
        if rising_edge(riu_clk_i) then
            if riu_ack_i then
                read_data <= (
                    GDDR6_RIU_DATA_BITS => std_ulogic_vector(riu_rd_data_i),
                    GDDR6_RIU_TIMEOUT_BIT => riu_error_i,
                    others => '0'
                );
            end if;
        end if;
    end process;
end;
