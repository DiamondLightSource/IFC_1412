-- Control and timing for SPI interface to multiplexed LMK devices

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity lmk04616_control is
    port (
        clk_i : in std_ulogic;

        command_select_i : in std_ulogic;
        select_valid_o : out std_ulogic;
        status_i : in std_ulogic_vector(1 downto 0);
        status_o : out std_ulogic_vector(1 downto 0);

        write_strobe_i : in std_ulogic;
        write_ack_o : out std_ulogic := '0';
        write_select_i : in std_ulogic;

        read_strobe_i : in std_ulogic;
        read_ack_o : out std_ulogic := '0';

        -- Control interface
        lmk_ctl_sel_o : out std_ulogic;
        spi_start_o : out std_ulogic := '0';
        spi_busy_i : in std_ulogic
    );
end;

architecture arch of lmk04616_control is
    type write_state_t is (WRITE_IDLE, WRITE_START, WRITE_BUSY);
    signal write_state : write_state_t := WRITE_IDLE;

    signal read_busy : std_ulogic := '0';

begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            case write_state is
                when WRITE_IDLE =>
                    -- Wait for write strobe, and use command_select_i to
                    -- control the LMK selection
                    write_ack_o <= '0';
                    if write_strobe_i then
                        write_state <= WRITE_START;
                        lmk_ctl_sel_o <= write_select_i;
                        spi_start_o <= '1';
                    else
                        lmk_ctl_sel_o <= command_select_i;
                        status_o <= status_i;
                    end if;
                when WRITE_START =>
                    if spi_busy_i then
                        write_state <= WRITE_BUSY;
                        spi_start_o <= '0';
                    end if;
                when WRITE_BUSY =>
                    if not spi_busy_i then
                        write_state <= WRITE_IDLE;
                        write_ack_o <= '1';
                    end if;
            end case;

            -- Reading when not writing can simply return response from last
            -- write, but a read overlapping a write must block for the write
            -- to complete.
            if write_state = WRITE_IDLE then
                read_busy <= '0';
            elsif read_strobe_i then
                -- Block this read until any write has completed
                read_busy <= '1';
            end if;
            read_ack_o <= to_std_ulogic(write_state = WRITE_IDLE) and
                (read_busy or read_strobe_i);
        end if;
    end process;

    select_valid_o <= to_std_ulogic(write_state = WRITE_IDLE);
end;
