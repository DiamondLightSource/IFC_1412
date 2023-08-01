-- Control over pin delays through RIU interface

-- If riu_vtc_handshake_i is set we follow the procedure documented
-- (repeatedly) for direct access to delay ports:
--  * First set EN_VTC low for the selected pin
--  * Wait for at least 10 clock ticks
--  * Pulse LOAD high for one clock tick (requires CNTVALUEIN to already
--    be valid on the previous tick; we already require this) if writing
--  * Wait for 10 ticks before restoring EN_VTC

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity gddr6_phy_riu_control is
    port (
        clk_i : std_ulogic;

        -- Register interface to user of PHY
        riu_addr_i : in unsigned(9 downto 0);
        riu_wr_data_i : in std_ulogic_vector(15 downto 0);
        riu_rd_data_o : out std_ulogic_vector(15 downto 0);
        riu_wr_en_i : in std_ulogic;
        riu_strobe_i : in std_ulogic;
        riu_ack_o : out std_ulogic;
        riu_error_o : out std_ulogic;
        riu_vtc_handshake_i : in std_ulogic;

        -- Interface to bitslice array
        riu_addr_o : out unsigned(9 downto 0);
        riu_wr_data_o : out std_ulogic_vector(15 downto 0);
        riu_rd_data_i : in std_ulogic_vector(15 downto 0);
        riu_valid_i : in std_ulogic;
        riu_wr_en_o : out std_ulogic;

        enable_vtc_o : out std_ulogic
    );
end;

architecture arch of gddr6_phy_riu_control is
    type state_t is (IDLE, WAIT_START, WAIT_VALID, WAIT_END);
    signal state : state_t := IDLE;
    signal wait_counter : natural range 0 to 9;

    signal riu_wr_en_out : std_ulogic := '0';
    signal riu_ack_out : std_ulogic := '0';
    signal enable_vtc_out : std_ulogic := '1';

begin
    process (clk_i)
        procedure goto_idle(valid_error : std_ulogic := '0') is
        begin
            riu_ack_out <= '1';
            enable_vtc_out <= '1';
            riu_error_o <= valid_error;
            state <= IDLE;
        end;

    begin
        if rising_edge(clk_i) then
            case state is
                when IDLE =>
                    -- Wait for strobe to start processing
                    riu_ack_out <= '0';
                    riu_wr_en_out <= '0';
                    wait_counter <= 9;
                    if riu_strobe_i then
                        -- Drive selected data and address.  Read data and the
                        -- valid signal will become valid on the next tick.
                        riu_addr_o <= riu_addr_i;
                        riu_wr_data_o <= riu_wr_data_i;
                        if riu_vtc_handshake_i then
                            -- If VTC handshake selected need to enter VTC wait
                            enable_vtc_out <= '0';
                            state <= WAIT_START;
                        else
                            state <= WAIT_VALID;
                        end if;
                    end if;
                when WAIT_START =>
                    -- Drop VTC for 10 ticks before reading or writing
                    if wait_counter > 0 then
                        wait_counter <= wait_counter - 1;
                    else
                        wait_counter <= 9;
                        state <= WAIT_VALID;
                    end if;
                when WAIT_VALID =>
                    -- Wait for valid signal.  The signal riu_valid_i is not
                    -- valid until riu_addr_o has been established, and we must
                    -- block until it is asserted.
                    if riu_valid_i then
                        riu_rd_data_o <= riu_rd_data_i;
                        riu_wr_en_out <= riu_wr_en_i;
                        if riu_vtc_handshake_i and riu_wr_en_i then
                            wait_counter <= 9;
                            state <= WAIT_END;
                        else
                            goto_idle;
                        end if;
                    elsif wait_counter > 0 then
                        wait_counter <= wait_counter - 1;
                    else
                        -- Oh dear oh dear oh dear.
                        -- The documentation doesn't say how long to wait, but
                        -- if we don't bail out now we will wedge the register
                        -- interface.  Fake an acknowledge and end.
                        goto_idle(valid_error => '1');
                    end if;
                when WAIT_END =>
                    -- Wait for wait counter before releasing VTC and ack
                    riu_wr_en_out <= '0';
                    if wait_counter > 0 then
                        wait_counter <= wait_counter - 1;
                    else
                        goto_idle;
                    end if;
            end case;
        end if;
    end process;

    riu_wr_en_o <= riu_wr_en_out;
    riu_ack_o <= riu_ack_out;
    enable_vtc_o <= enable_vtc_out;
end;
