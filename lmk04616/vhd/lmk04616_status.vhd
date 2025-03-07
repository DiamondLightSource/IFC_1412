-- Provides relatively up to date monitoring of SYS and ACQ status bits

-- Because access to the two LMK clock controllers is multiplexed we cannot
-- provide live access to the status bits.  Instead while access is allowed we
-- continually toggle the selection and update the appropriate status bits.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.register_defs.all;

entity lmk04616_status is
    generic (
        -- log2 of status poll interval in ticks
        STATUS_POLL_BITS : natural
    );
    port (
        clk_i : in std_ulogic;

        -- Direction request to controller and current status
        ctrl_sel_o : out std_ulogic;
        ctrl_idle_i : in std_ulogic;

        -- Current selection and status readbacks
        lmk_sel_i : in std_ulogic;
        lmk_status_i : in std_ulogic_vector(0 to 1);

        -- Selected status readbacks
        sys_status_o : out std_ulogic_vector(0 to 1);
        acq_status_o : out std_ulogic_vector(0 to 1)
    );
end;

architecture arch of lmk04616_status is
    signal poll_counter : unsigned(STATUS_POLL_BITS downto 0)
        := (others => '0');

begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Free running counter
            poll_counter <= poll_counter + 1;
            -- Toggle the selection request as the counter rolls over
            ctrl_sel_o <= poll_counter(STATUS_POLL_BITS);
            -- Only update state while the controller is idle
            if ctrl_idle_i then
                case lmk_sel_i is
                    when '0' =>
                        sys_status_o <= lmk_status_i;
                    when '1' =>
                        acq_status_o <= lmk_status_i;
                    when others =>
                end case;
            end if;
        end if;
    end process;
end;
