-- Delay register control

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.gddr6_register_defines.all;
use work.gddr6_defs.all;

entity gddr6_setup_delay is
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
        setup_delay_o : out setup_delay_t;
        setup_delay_i : in setup_delay_result_t
    );
end;

architecture arch of gddr6_setup_delay is
    -- Entire control is on ck clock
    signal write_strobe : std_ulogic;
    signal write_data : reg_data_t;
    signal write_ack : std_ulogic := '0';
    signal read_strobe : std_ulogic;
    signal read_data : reg_data_t;
    signal read_ack : std_ulogic := '0';

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

    setup_delay_o <= (
        address => unsigned(write_data(GDDR6_DELAY_ADDRESS_BITS)),
        target => unsigned(write_data(GDDR6_DELAY_TARGET_BITS)),
        delay => unsigned(write_data(GDDR6_DELAY_DELAY_BITS)),
        up_down_n => write_data(GDDR6_DELAY_UP_DOWN_N_BIT),
        enable_write => write_data(GDDR6_DELAY_ENABLE_WRITE_BIT),
        write_strobe => write_strobe,
        read_strobe => read_strobe
    );

    write_ack <= setup_delay_i.write_ack;

    process (ck_clk_i) begin
        if rising_edge(ck_clk_i) then
            read_ack <= setup_delay_i.read_ack;

            -- Capture read data on completion of read
            if setup_delay_i.read_ack then
                read_data <= (
                    GDDR6_DELAY_DELAY_BITS =>
                        std_ulogic_vector(setup_delay_i.delay),
                    others => '0');
            end if;
        end if;
    end process;
end;
