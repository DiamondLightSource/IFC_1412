-- Central control of SPI transaction

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.register_defs.all;
use work.register_defines.all;

entity flash_control is
    port (
        clk_i : in std_ulogic;

        -- Register interface
        write_strobe_i : in std_ulogic;
        write_data_i : in reg_data_t;
        write_ack_o : out std_ulogic;
        read_strobe_i : in std_ulogic;
        read_data_o : out reg_data_t;
        read_ack_o : out std_ulogic;

        -- SPI transaction settings: selection and speed
        select_spi_o : out std_ulogic_vector(1 downto 0) := "00";
        read_delay_o : out unsigned(2 downto 0);
        clock_speed_o : out unsigned(1 downto 0);
        long_cs_high_o : out std_ulogic;

        -- Read control
        read_enable_o : out std_ulogic := '0';

        -- Core control
        core_start_o : out std_ulogic := '0';
        core_last_o : out std_ulogic := '0';
        core_next_i : in std_ulogic;
        core_busy_i : in std_ulogic
    );
end;

architecture arch of flash_control is
    type state_t is (SPI_IDLE, SPI_ACTIVE, SPI_ENDING);
    signal state : state_t := SPI_IDLE;

    -- Number of bytes (-1) to send or receive in this transaction
    signal length : unsigned(9 downto 0);
    -- Offset of first byte to receive
    signal read_offset : unsigned(9 downto 0);

begin
    -- This is a write only register which returns zeros when read
    read_data_o <= (others => '0');
    read_ack_o <= '1';

    process (clk_i)
        variable length_in : unsigned(9 downto 0);

    begin
        if rising_edge(clk_i) then
            length_in := unsigned(write_data_i(FLASH_COMMAND_LENGTH_BITS));

            case state is
                when SPI_IDLE =>
                    write_ack_o <= '0';
                    read_enable_o <= '0';

                    if write_strobe_i then
                        -- Capture control parameters
                        length <= length_in - 1;
                        read_offset <= unsigned(
                            write_data_i(FLASH_COMMAND_READ_OFFSET_BITS));
                        select_spi_o <=
                            write_data_i(FLASH_COMMAND_SELECT_BITS);
                        read_delay_o <= unsigned(
                            write_data_i(FLASH_COMMAND_READ_DELAY_BITS));
                        clock_speed_o <= unsigned(
                            write_data_i(FLASH_COMMAND_CLOCK_SPEED_BITS));
                        long_cs_high_o <=
                            write_data_i(FLASH_COMMAND_LONG_CS_HIGH_BIT);

                        core_last_o <= to_std_ulogic(length_in = 0);
                        core_start_o <= '1';
                        state <= SPI_ACTIVE;
                    end if;

                when SPI_ACTIVE =>
                    core_start_o <= '0';

                    if core_next_i then
                        if core_last_o then
                            -- End of the last transaction
                            state <= SPI_ENDING;
                        else
                            -- Prepare for the next transaction
                            core_last_o <= to_std_ulogic(length = 0);
                            length <= length - 1;
                            if read_offset > 0 then
                                read_offset <= read_offset - 1;
                            else
                                read_enable_o <= '1';
                            end if;
                        end if;
                    end if;

                when SPI_ENDING =>
                    -- Wait for the core to become idle before we acknowledge
                    if not core_busy_i then
                        write_ack_o <= '1';
                        state <= SPI_IDLE;
                    end if;
            end case;
        end if;
    end process;
end;
