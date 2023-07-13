-- Clocking and resets

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.support.all;

entity gddr6_phy_clocking is
    generic (
        CK_FREQUENCY : real
    );
    port (
        -- Main clock and reset control.  Hold in reset until CK valid
        ck_clk_o : out std_ulogic;
        ck_reset_i : in std_ulogic;
        ck_ok_o : out std_ulogic;
        ck_unlock_o : out std_ulogic;

        -- Clock in from SG12_CK and TX clock out to bitslices
        io_ck_i : in std_ulogic;
        pll_clk_o : out std_ulogic_vector(0 to 1);

        -- Reset control and management
        reset_o : out std_ulogic;                -- Bitslice reset
        dly_ready_i : in std_ulogic;           -- Delay ready (async)
        vtc_ready_i : in std_ulogic;           -- Calibration done (async)
        enable_control_vtc_o : out std_ulogic
    );
end;

architecture arch of gddr6_phy_clocking is
    signal io_ck_in : std_ulogic;
    signal clock_out : std_ulogic_vector(0 to 1);
    signal pll_locked : std_ulogic_vector(0 to 1);
    signal unlock_detect : std_ulogic;
    signal clk : std_ulogic;

    signal reset_sync : std_ulogic;
    signal dly_ready_in : std_ulogic;
    signal vtc_ready_in : std_ulogic;
    type reset_state_t is (
        RESET_START, RESET_RELEASE, RESET_WAIT_PLL, RESET_WAIT_DLY_RDY,
        RESET_WAIT_VTC_RDY, RESET_DONE);
    signal reset_state : reset_state_t := RESET_START;
    signal wait_counter : unsigned(5 downto 0);
    signal enable_pll_clk : std_ulogic := '0';

begin
    bufg_in : BUFG port map(
        I => io_ck_i,
        O => io_ck_in
    );

    gen_plls : for i in 0 to 1 generate
        signal clkfb : std_ulogic;
    begin
        -- Input clock is 250 or 300 MHz, the PLL runs at 1 or 1.2 GHz
        pll : PLLE3_BASE generic map (
            CLKFBOUT_MULT => 4,
            CLKFBOUT_PHASE => 0.0,
            CLKIN_PERIOD => 1000.0 / CK_FREQUENCY,
            CLKOUT0_DIVIDE => 4,
            CLKOUTPHY_MODE => "VCO_2X" -- 2 or 2.4 GHz on CLKOUTPHY
        ) port map (
            CLKIN => io_ck_in,
            CLKOUTPHY => pll_clk_o(i),
            CLKOUT0 => clock_out(i),
            CLKFBOUT => clkfb,
            CLKFBIN => clkfb,
            LOCKED => pll_locked(i),
            CLKOUTPHYEN => enable_pll_clk,
            PWRDWN => '0',
            RST => ck_reset_i
        );
    end generate;

    -- Enable the global clock once we're out of reset and the PLL is locked
    bufg_out : BUFGCE port map (
        I => clock_out(0),
        O => clk,
        CE => vector_and(pll_locked) and not ck_reset_i
    );
    ck_clk_o <= clk;


    -- Synchronise reset with clock for the remaining processing
    sync_reset : entity work.sync_bit generic map (
        INITIAL => '1'
    ) port map (
        clk_i => clk,
        reset_i => ck_reset_i,
        bit_i => '0',
        bit_o => reset_sync
    );

    sync_dly_ready : entity work.sync_bit port map (
        clk_i => clk,
        bit_i => dly_ready_i,
        bit_o => dly_ready_in
    );

    sync_vtc_ready : entity work.sync_bit port map (
        clk_i => clk,
        bit_i => vtc_ready_i,
        bit_o => vtc_ready_in
    );


    -- Generate reset sequence.  This follows the reset process documented in
    -- UG571 starting on p296 of v1.14.
    --
    -- ... still need to sort out pull ups of TBYTE_IN ... don't
    -- actually understand this ...
    process (clk, reset_sync) begin
        if reset_sync then
            reset_state <= RESET_START;
            enable_control_vtc_o <= '0';
            reset_o <= '1';
            enable_pll_clk <= '0';
            ck_ok_o <= '0';
        elsif rising_edge(clk) then
            case reset_state is
                when RESET_START =>
                    -- Just wait one tick before we do anything
                    reset_state <= RESET_RELEASE;
                when RESET_RELEASE =>
                    -- Release reset and start counting before releasing PLL
                    reset_o <= '0';
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
                    enable_pll_clk <= '1';
                    if dly_ready_in then
                        enable_control_vtc_o <= '1';
                        reset_state <= RESET_WAIT_VTC_RDY;
                    end if;
                when RESET_WAIT_VTC_RDY =>
                    -- Wait for VTC_RDY
                    if vtc_ready_in then
                        reset_state <= RESET_DONE;
                        ck_ok_o <= '1';
                    end if;
                when RESET_DONE =>
                    -- We stay in this state unless another reset occurs
            end case;
        end if;
    end process;

    -- Detect PLL unlock and generate single pulse on resumption of lock
    process (clk, pll_locked) begin
        if not vector_and(pll_locked) then
            unlock_detect <= '1';
        elsif rising_edge(clk) then
            unlock_detect <= '0';
            ck_unlock_o <= unlock_detect;
        end if;
    end process;
end;
