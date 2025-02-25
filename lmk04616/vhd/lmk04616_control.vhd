-- Control and timing for SPI interface to multiplexed LMK devices

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.lmk04616_defines.all;

entity lmk04616_control is
    port (
        clk_i : in std_ulogic;

        -- Register interface
        write_strobe_i : in std_ulogic;
        write_data_i : in reg_data_t;
        write_ack_o : out std_ulogic := '0';
        read_strobe_i : in std_ulogic;
        read_data_o : out reg_data_t;
        read_ack_o : out std_ulogic := '0';

        -- Miscellaneous controls
        lmk_ctl_sel_o : out std_ulogic := '0';
        lmk_reset_l_o : out std_ulogic := '1';
        lmk_sync_o : out std_ulogic := '0';
        lmk_status_i : in std_ulogic_vector(0 to 1);

        -- Interface to SPI
        spi_read_write_n_o : out std_ulogic := '0';
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

    signal write_strobe_in : std_ulogic;
    signal read_strobe_in : std_ulogic;

begin
    -- Read and write acknowledge control
    write_strobe_ack : entity work.strobe_ack port map (
        clk_i => clk_i,
        strobe_i => write_strobe_i,
        ack_o => write_ack_o,
        busy_i => to_std_ulogic(write_state /= WRITE_IDLE),
        strobe_o => write_strobe_in
    );

    read_strobe_ack : entity work.strobe_ack port map (
        clk_i => clk_i,
        strobe_i => read_strobe_i,
        ack_o => read_ack_o,
        busy_i => to_std_ulogic(write_state /= WRITE_IDLE),
        strobe_o => read_strobe_in
    );


    process (clk_i) begin
        if rising_edge(clk_i) then
            case write_state is
                when WRITE_IDLE =>
                    -- Wait for write strobe, and use .SELECT to control the
                    -- LMK selection
                    if write_strobe_in then
                        -- Register all incoming data on write strobe
                        spi_data_o <= write_data_i(LMK04616_DATA_BITS);
                        spi_address_o <= write_data_i(LMK04616_ADDRESS_BITS);
                        spi_read_write_n_o <= write_data_i(LMK04616_R_WN_BIT);
                        lmk_ctl_sel_o <= write_data_i(LMK04616_SELECT_BIT);
                        lmk_reset_l_o <= not write_data_i(LMK04616_RESET_BIT);
                        lmk_sync_o <= write_data_i(LMK04616_SYNC_BIT);

                        if write_data_i(LMK04616_ENABLE_BIT) then
                            write_state <= WRITE_START;
                        end if;
                    end if;
                when WRITE_START =>
                    if spi_busy_i then
                        write_state <= WRITE_BUSY;
                    end if;
                when WRITE_BUSY =>
                    if not spi_busy_i then
                        write_state <= WRITE_IDLE;
                    end if;
            end case;

            if read_strobe_in then
                -- Assemble outgoing data
                read_data_o <= (
                    LMK04616_DATA_BITS => spi_data_i,
                    LMK04616_ADDRESS_BITS => spi_address_o,
                    LMK04616_SELECT_BIT => lmk_ctl_sel_o,
                    LMK04616_RESET_BIT => not lmk_reset_l_o,
                    LMK04616_SYNC_BIT => lmk_sync_o,
                    LMK04616_STATUS_BITS => reverse(lmk_status_i),
                    others => '0'
                );
            end if;
        end if;
    end process;

    spi_start_o <= to_std_ulogic(write_state = WRITE_START);
end;

-- vim: set filetype=vhdl:
