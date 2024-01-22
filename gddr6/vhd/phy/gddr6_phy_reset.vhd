-- Bitslice reset control

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.support.all;

entity gddr6_phy_reset is
    port (
        -- The bitslice reset uses the RIU clock
        clk_i : in std_ulogic;
        ck_clk_ok_o : out std_ulogic;

        -- MMCM and PLL status
        pll_locked_i : in std_ulogic;       -- Already synchronous with RIU
        mmcm_locked_i : in std_ulogic;

        -- Reset control and management
        ck_reset_i : in std_ulogic;
        dly_ready_i : in std_ulogic;        -- Delay ready (async)
        vtc_ready_i : in std_ulogic;        -- Calibration done (async)
        enable_pll_phy_o : out std_ulogic;
        bitslice_reset_o : out std_ulogic;  -- Bitslice reset
        enable_control_vtc_o : out std_ulogic;
        enable_bitslice_vtc_o : out std_ulogic;
        enable_bitslice_control_o : out std_ulogic
    );
end;

architecture arch of gddr6_phy_reset is
    -- Synchronise incoming status signals
    signal reset_sync : std_ulogic;
    signal dly_ready_in : std_ulogic;
    signal vtc_ready_in : std_ulogic;

    type reset_state_t is (
        RESET_START, RESET_RELEASE, RESET_WAIT_PLL, RESET_WAIT_DLY_RDY,
        RESET_WAIT_VTC_RDY, RESET_DONE);
    signal reset_state : reset_state_t := RESET_START;
    signal wait_counter : unsigned(5 downto 0);

begin
    -- Synchronise reset with clock for the remaining processing
    sync_reset : entity work.sync_bit generic map (
        INITIAL => '1'
    ) port map (
        clk_i => clk_i,
        reset_i => ck_reset_i,
        bit_i => '0',
        bit_o => reset_sync
    );

    sync_dly_ready : entity work.sync_bit port map (
        clk_i => clk_i,
        bit_i => dly_ready_i,
        bit_o => dly_ready_in
    );

    sync_vtc_ready : entity work.sync_bit port map (
        clk_i => clk_i,
        bit_i => vtc_ready_i,
        bit_o => vtc_ready_in
    );


    -- Generate reset sequence.  This follows the reset process documented in
    -- UG571 starting on p296 of v1.14.
    process (clk_i, reset_sync) begin
        if reset_sync then
            reset_state <= RESET_START;
            enable_control_vtc_o <= '0';
            enable_bitslice_vtc_o <= '1';
            bitslice_reset_o <= '1';
            enable_pll_phy_o <= '0';
            enable_bitslice_control_o <= '0';
            wait_counter <= 6X"0F";
        elsif rising_edge(clk_i) then
            case reset_state is
                when RESET_START =>
                    -- Wait a few ticks before we do anything.  Note that this
                    -- event will not occur until the MMCM is out of reset, as
                    -- the clock is qualified by clk_enable.
                    if wait_counter > 0 then
                        wait_counter <= wait_counter - 1;
                    elsif pll_locked_i then
                        -- In case the PLLs are late coming into lock wait for
                        -- them as well
                        reset_state <= RESET_RELEASE;
                    end if;
                when RESET_RELEASE =>
                    -- Release bitslice resets and start counting before
                    -- enabling the high speed clock
                    bitslice_reset_o <= '0';
                    wait_counter <= 6X"3F";     -- 63 ticks
                    reset_state <= RESET_WAIT_PLL;
                when RESET_WAIT_PLL =>
                    -- Wait 64 clocks for PLL to be good
                    wait_counter <= wait_counter - 1;
                    if wait_counter = 0 then
                        reset_state <= RESET_WAIT_DLY_RDY;
                    end if;
                when RESET_WAIT_DLY_RDY =>
                    -- Enable the pll clock to slices and wait for DLY_RDY
                    enable_pll_phy_o <= '1';
                    if dly_ready_in then
                        reset_state <= RESET_WAIT_VTC_RDY;
                    end if;
                when RESET_WAIT_VTC_RDY =>
                    -- Wait for VTC_RDY
                    enable_control_vtc_o <= '1';
                    if vtc_ready_in then
                        reset_state <= RESET_DONE;
                    end if;
                when RESET_DONE =>
                    -- We stay in this state unless another reset occurs
                    enable_bitslice_control_o <= '1';
                    -- Now turn bitslice VTC off for the remainder of operation
                    enable_bitslice_vtc_o <= '0';
            end case;
        end if;
    end process;

    -- Ensure we report CK not ok if we lose valid CK at any time
    ck_clk_ok_o <= to_std_ulogic(reset_state = RESET_DONE) and mmcm_locked_i;
end;
