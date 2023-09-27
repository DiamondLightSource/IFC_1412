-- Delay register control

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.gddr6_register_defines.all;

entity gddr6_setup_delay is
    generic (
        -- Delay readback is quite expensive in terms of fabric, so is optional
        READBACK_DELAY : boolean
    );
    port (
        ck_clk_i : in std_ulogic;       -- CK clock
        ck_clk_ok_i : in std_ulogic;    -- CK and RIU clocks ok
        reg_clk_i : in std_ulogic;      -- Register clock

        -- Register interface
        write_strobe_i : in std_ulogic;
        write_data_i : in reg_data_t;
        write_ack_o : out std_ulogic;
        read_strobe_i : in std_ulogic;
        read_data_o : out reg_data_t;
        read_ack_o : out std_ulogic;

        -- Delay control on delay_clk_i
        delay_address_o : out unsigned(7 downto 0);
        delay_o : out unsigned(7 downto 0);
        delay_up_down_n_o : out std_ulogic;
        delay_strobe_o : out std_ulogic;
        delay_ack_i : in std_ulogic;
        -- Individual delay readbacks
        read_delay_address_o : out unsigned(7 downto 0);
        read_delay_i : in unsigned(8 downto 0)
    );
end;

architecture arch of gddr6_setup_delay is
    -- Entire control is on ck clock
    signal write_strobe : std_ulogic;
    signal write_data : reg_data_t;
    signal write_ack : std_ulogic;
    signal read_strobe : std_ulogic;
    signal read_data : reg_data_t;
    signal read_ack : std_ulogic;

    signal suppress_write : std_ulogic;
    signal full_delay_out : unsigned(8 downto 0);

begin
    -- Bring the delay register over to the CK domain
    cc : entity work.register_cc port map (
        clk_in_i => reg_clk_i,
        clk_out_i => ck_clk_i,
        clk_out_ok_i => ck_clk_ok_i,

        write_data_i(0) => write_data_i,
        write_strobe_i(0) => write_strobe_i,
        write_ack_o(0) => write_ack_o,
        read_data_o(0) => read_data_o,
        read_strobe_i(0) => read_strobe_i,
        read_ack_o(0) => read_ack_o,

        write_data_o(0) => write_data,
        write_strobe_o(0) => write_strobe,
        write_ack_i(0) => write_ack,
        read_data_i(0) => read_data,
        read_strobe_o(0) => read_strobe,
        read_ack_i(0) => read_ack
    );

    read_ack <= '1';

    suppress_write <= write_data(GDDR6_DELAY_NO_WRITE_BIT);
    full_delay_out <= unsigned(write_data(GDDR6_DELAY_DELAY_BITS));
    process (ck_clk_i) begin
        if rising_edge(ck_clk_i) then
            delay_address_o <= unsigned(write_data(GDDR6_DELAY_ADDRESS_BITS));
            read_delay_address_o <=
                unsigned(write_data(GDDR6_DELAY_ADDRESS_BITS));
            delay_o <= full_delay_out(delay_o'RANGE);
            delay_up_down_n_o <= write_data(GDDR6_DELAY_UP_DOWN_N_BIT);

            delay_strobe_o <= write_strobe and not suppress_write;
            write_ack <= delay_ack_i or (suppress_write and write_strobe);

            if READBACK_DELAY then
                read_data <= (
                    GDDR6_DELAY_ADDRESS_BITS =>
                        std_ulogic_vector(read_delay_address_o),
                    GDDR6_DELAY_DELAY_BITS => std_ulogic_vector(read_delay_i),
                    others => '0');
            end if;
        end if;
    end process;
end;
