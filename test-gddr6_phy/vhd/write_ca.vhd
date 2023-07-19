-- Simple writing to CA

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.register_defs.all;
use work.register_defines.all;

entity write_ca is
    port (
        clk_i : in std_ulogic;
        write_strobe_i : in std_ulogic;
        write_data_i : in reg_data_t;
        write_ack_o : out std_ulogic;

        ca_o : out vector_array(0 to 1)(9 downto 0);
        ca3_o : out std_ulogic_vector(0 to 3);
        cke_n_o : out std_ulogic
    );
end;

architecture arch of write_ca is
    constant cmd_NOP : vector_array(0 to 1)(9 downto 0)
        := (others => (others => '1'));

    signal hold : std_ulogic;

    signal ca_out : vector_array(0 to 1)(9 downto 0) := cmd_NOP;
    signal ca3_out : std_ulogic_vector(0 to 3) := "0000";
    signal cke_n_out : std_ulogic := '0';
    signal write_ack_out : std_ulogic := '0';

begin
    -- Perform command
    process (clk_i) begin
        if rising_edge(clk_i) then
            if write_strobe_i then
                ca_out <= (
                    0 => write_data_i(PHY_CA_RISING_BITS),
                    1 => write_data_i(PHY_CA_FALLING_BITS)
                );
                ca3_out <= write_data_i(PHY_CA_CA3_BITS);
                cke_n_out <= write_data_i(PHY_CA_CKE_N_BIT);
                hold <= write_data_i(PHY_CA_HOLD_BIT);
            elsif not hold then
                ca_out <= cmd_NOP;
                ca3_out <= "0000";
                cke_n_out <= '0';
            end if;
            write_ack_out <= write_strobe_i;
        end if;
    end process;

    write_ack_o <= write_ack_out;
    ca_o <= ca_out;
    ca3_o <= ca3_out;
    cke_n_o <= cke_n_out;
end;
