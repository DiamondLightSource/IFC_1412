-- Simple simulation of LMK SPI slave

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity sim_lmk04616 is
    port (
        pad_LMK_CTL_SEL_i : in std_ulogic;
        pad_LMK_SCL_i : in std_ulogic;
        pad_LMK_SCS_L_i : in std_ulogic;
        pad_LMK_SDIO_io : inout std_logic;
        pad_LMK_RESET_L_i : in std_ulogic;
        pad_LMK_SYNC_io : inout std_logic;
        pad_LMK_STATUS_io : inout std_logic_vector(1 downto 0)
    );
end;

architecture arch of sim_lmk04616 is
    signal r_wn : std_ulogic;
    signal address : unsigned(14 downto 0);
    signal data_in : std_ulogic_vector(7 downto 0);
    signal data_out : std_ulogic_vector(7 downto 0);

    signal storage : vector_array_array(0 to 1)(0 to 15)(7 downto 0)
        := (others => (others => (others => '0')));

begin
    pad_LMK_SYNC_io <= 'Z';

    -- SPI slave
    process begin
        pad_LMK_SDIO_io <= 'Z';
        -- Wait for SCS low
        wait until falling_edge(pad_LMK_SCS_L_i);
        -- Pick up Read/Write* flag
        wait until rising_edge(pad_LMK_SCL_i);
        r_wn <= pad_LMK_SDIO_io;
        -- Read address
        for i in 0 to 14 loop
            wait until rising_edge(pad_LMK_SCL_i);
            address <= address(13 downto 0) & pad_LMK_SDIO_io;
        end loop;
        case r_wn is
            when '0' =>
                -- Write incoming data to selected address
                for i in 0 to 7 loop
                    wait until rising_edge(pad_LMK_SCL_i);
                    data_in <= data_in(6 downto 0) & pad_LMK_SDIO_io;
                end loop;
                wait for 1 ps;  -- Hack to let data_in update
                storage
                    (to_integer(pad_LMK_CTL_SEL_i))
                    (to_integer(address(3 downto 0))) <= data_in;
            when '1' =>
                -- Return value read from selected address
                wait for 1 ps;  -- Hack to let address update
                data_out <= storage
                    (to_integer(pad_LMK_CTL_SEL_i))
                    (to_integer(address(3 downto 0)));
                for i in 0 to 7 loop
                    wait until falling_edge(pad_LMK_SCL_i);
                    pad_LMK_SDIO_io <= data_out(7);
                    data_out <= data_out(6 downto 0) & '0';
                end loop;
            when others =>
                assert False severity failure;  -- Don't do this!
        end case;
        wait until rising_edge(pad_LMK_SCS_L_i);
    end process;

    -- Simple status readback reports selected LMK
    process (all) begin
        case pad_LMK_CTL_SEL_i is
            when '0' =>
                pad_LMK_STATUS_io <= "01";
            when '1' =>
                pad_LMK_STATUS_io <= "10";
            when others =>
        end case;
    end process;
end;
