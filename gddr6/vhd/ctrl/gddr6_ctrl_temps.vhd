-- Read temperatures

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_ctrl_command_defs.all;
use work.gddr6_ctrl_timing_defs.all;
use work.gddr6_ctrl_delay_defs.all;

entity gddr6_ctrl_temps is
    port (
        clk_i : in std_ulogic;

        refresh_start_i : in std_ulogic;
        command_o : out ca_command_t;
        command_valid_o : out std_ulogic := '0';
        data_i : in phy_data_t;

        temperature_o : out sg_temperature_t := INVALID_TEMPERATURE
    );
end;

architecture arch of gddr6_ctrl_temps is
    -- We have t_RFCab = 28 ticks to read the temperatures, which involves the
    -- following steps:
    --  * Wait for calibration to complete (t_KO)
    --  * Issue READ_TEMPS MRS 3 command to read the temperatures
    --  * Wait long enough for data to be valid and read
    --  * Issue VENDOR_OFF MRS 3 command to restore normal operation
    -- Separately, the data is read when valid

    -- Wait for REFab calibration to complete.  Nominally this is t_KO which is
    -- just under 4 ticks, we add an extra tick for comfort
    constant READ_TEMPS_DELAY : natural := t_KO + 1;
    -- The temperature data is available within t_WRIDON (3 ticks), but we leave
    -- it active for a further 3 ticks so that reading is comfortable.
    constant VENDOR_OFF_DELAY : natural := t_WRIDON + 3;
    -- Before reading the data we need to wait for the round trip delay to the
    -- hardware, and we add on a couple more ticks for comfort
    constant READ_DATA_DELAY : natural :=
        CA_OUTPUT_DELAY + t_WRIDON + RX_INPUT_DELAY + 2;
    -- A somewhat arbitrary delay: ensures that the temperature data is valid
    constant DATA_VALID_DELAY : natural := 6;

    signal do_read_temps : std_ulogic;
    signal do_vendor_off : std_ulogic;
    signal do_read_data : std_ulogic;
    signal do_data_valid : std_ulogic;

    impure function get_temperature(ch : natural) return unsigned is
        variable result : unsigned(7 downto 0);
    begin
        for b in 0 to 7 loop
            result(b) := data_i(16*ch + b)(0);
        end loop;
        return result;
    end;

    -- Mark the entire temperature_o structure as the source of a false path:
    -- readers required to use a synchronisation handshake when reading it.
    attribute FALSE_PATH_FROM : string;
    attribute KEEP : string;
    attribute FALSE_PATH_FROM of temperature_o : signal is "TRUE";
    attribute KEEP of temperature_o : signal is "TRUE";

begin
    -- Trigger everything from refresh_start
    start : entity work.fixed_delay generic map (
        DELAY => READ_TEMPS_DELAY
    ) port map (
        clk_i => clk_i,
        data_i(0) => refresh_start_i,
        data_o(0) => do_read_temps
    );

    finish : entity work.fixed_delay generic map (
        DELAY => VENDOR_OFF_DELAY
    ) port map (
        clk_i => clk_i,
        data_i(0) => do_read_temps,
        data_o(0) => do_vendor_off
    );

    read : entity work.fixed_delay generic map (
        DELAY => READ_DATA_DELAY
    ) port map (
        clk_i => clk_i,
        data_i(0) => do_read_temps,
        data_o(0) => do_read_data
    );

    valid : entity work.fixed_delay generic map (
        DELAY => DATA_VALID_DELAY
    ) port map (
        clk_i => clk_i,
        data_i(0) => do_read_data,
        data_o(0) => do_data_valid
    );

    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Command generation
            if do_read_temps then
                command_o <= SG_READ_TEMPS;
                command_valid_o <= '1';
            elsif do_vendor_off then
                command_o <= SG_VENDOR_OFF;
                command_valid_o <= '1';
            else
                command_valid_o <= '0';
            end if;

            -- Data valid flag
            if do_read_temps then
                temperature_o.valid <= '0';
            elsif do_data_valid then
                temperature_o.valid <= '1';
            end if;

            -- Data capture
            if do_read_data then
                for ch in 0 to 3 loop
                    temperature_o.temperature(ch) <= get_temperature(ch);
                end loop;
            end if;
        end if;
    end process;
end;
