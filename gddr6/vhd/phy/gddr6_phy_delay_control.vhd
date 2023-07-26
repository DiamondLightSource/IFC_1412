-- Need to rename this to gddr6_phy_riu !!!!


-- Control over pin delays

-- Multiplexes selection of the appropriate pin and ensures that the VAR_LOAD
-- procedure for updating and reading delays is properly followed:
--  * First set EN_VTC low for the selected pin
--  * Wait for at least 10 clock ticks
--  * Pulse LOAD high for one clock tick (requires CNTVALUEIN to already
--    be valid on the previous tick; we already require this) if writing
--  * Wait for 10 ticks before restoring EN_VTC
--  * Valid delay is captured after LOAD

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity gddr6_phy_delay_control is
    port (
        clk_i : std_ulogic;

        -- Register interface to user of PHY
        riu_addr_i : in unsigned(9 downto 0);
        riu_wr_data_i : in std_ulogic_vector(15 downto 0);
        riu_rd_data_o : out std_ulogic_vector(15 downto 0);
        riu_wr_en_i : in std_ulogic;
        riu_strobe_i : in std_ulogic;
        riu_ack_o : out std_ulogic;

        -- Interface to bitslice array
        riu_addr_o : out unsigned(9 downto 0);
        riu_wr_data_o : out std_ulogic_vector(15 downto 0);
        riu_rd_data_i : in std_ulogic_vector(15 downto 0);
        riu_valid_i : in std_ulogic;
        riu_wr_en_o : out std_ulogic;

        enable_vtc_o : out std_ulogic
    );
end;

architecture arch of gddr6_phy_delay_control is
    type state_t is (IDLE, BUSY);
    signal state : state_t := IDLE;

    signal riu_ack_out : std_ulogic := '0';

begin
    -- For the time being we just unconditionally assert VTC
    enable_vtc_o <= '1';

    process (clk_i) begin
        if rising_edge(clk_i) then
            case state is
                when IDLE => -- Wait for strobe to start processing
                    riu_ack_out <= '0';
                    if riu_strobe_i then
                        -- For convenience register all parameters now
                        riu_addr_o <= riu_addr_i;
                        riu_wr_data_o <= riu_wr_data_i;
                        riu_wr_en_o <= riu_wr_en_i;
                        state <= BUSY;
                    end if;
                when BUSY =>
                    riu_wr_en_o <= '0';
                    if riu_valid_i then
                        riu_rd_data_o <= riu_rd_data_i;
                        riu_ack_out <= '1';
                        state <= IDLE;
                    end if;
            end case;
        end if;
    end process;
    riu_ack_o <= riu_ack_out;
end;
