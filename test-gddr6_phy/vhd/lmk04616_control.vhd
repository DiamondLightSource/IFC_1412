-- Control and timing for SPI interface to multiplexed LMK devices

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.register_defines.all;

entity lmk04616_control is
    port (
        clk_i : in std_ulogic;

        -- Static configuration
        command_select_i : in std_ulogic;
        select_valid_o : out std_ulogic;
        status_i : in std_ulogic_vector(1 downto 0);
        status_o : out std_ulogic_vector(1 downto 0);

        -- Register interface
        write_strobe_i : in std_ulogic;
        write_data_i : in reg_data_t;
        write_ack_o : out std_ulogic;
        read_strobe_i : in std_ulogic;
        read_data_o : out reg_data_t;
        read_ack_o : out std_ulogic;

        -- Control interface to SPI
        lmk_ctl_sel_o : out std_ulogic;
        spi_read_write_n_o : out std_ulogic;
        spi_address_o : out std_ulogic_vector(14 downto 0);
        spi_start_o : out std_ulogic := '0';
        spi_busy_i : in std_ulogic;
        spi_data_i : in std_ulogic_vector(7 downto 0);
        spi_data_o : out std_ulogic_vector(7 downto 0)
    );
end;

architecture arch of lmk04616_control is
    type write_state_t is (WRITE_IDLE, WRITE_START, WRITE_BUSY);
    signal write_state : write_state_t := WRITE_IDLE;

    signal read_busy : std_ulogic := '0';
    signal spi_write_select : std_ulogic;

begin
    -- Decode incoming write
    spi_address_o <= write_data_i(SYS_LMK04616_ADDRESS_BITS);
    spi_data_o <= write_data_i(SYS_LMK04616_DATA_BITS);
    spi_read_write_n_o <= write_data_i(SYS_LMK04616_R_WN_BIT);
    spi_write_select <= write_data_i(SYS_LMK04616_SELECT_BIT);

    -- Assemble outgoing data
    read_data_o <= (
        SYS_LMK04616_DATA_BITS => spi_data_i,
        others => '0'
    );

    process (clk_i) begin
        if rising_edge(clk_i) then
            case write_state is
                when WRITE_IDLE =>
                    -- Wait for write strobe, and use spi_write_select to
                    -- control the LMK selection
                    write_ack_o <= '0';
                    if write_strobe_i then
                        write_state <= WRITE_START;
                        lmk_ctl_sel_o <= spi_write_select;
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
