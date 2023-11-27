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
        -- Main clock and reset control.  Hold in reset until CK input valid
        ck_clk_o : out std_ulogic;
        -- Dedicated clock for bitslice RIU.  This is needed for the bitslice
        -- control, but cannot run at full CK clock speed
        riu_clk_o : out std_ulogic;

        -- Resets and clock status
        ck_reset_i : in std_ulogic;
        ck_clk_ok_o : out std_ulogic;
        ck_unlock_o : out std_ulogic;

        -- Clock in from SG12_CK and TX clock out to bitslices
        io_ck_i : in std_ulogic;
        phy_clk_o : out std_ulogic_vector(0 to 1);

        -- Reset control and management
        bitslice_reset_o : out std_ulogic;     -- Bitslice reset
        dly_ready_i : in std_ulogic;           -- Delay ready (async)
        vtc_ready_i : in std_ulogic;           -- Calibration done (async)
        enable_control_vtc_o : out std_ulogic;
        enable_bitslice_control_o : out std_ulogic
    );
end;

architecture arch of gddr6_phy_clocking is
    signal io_ck_in : std_ulogic;
    signal ck_clock_out : std_ulogic_vector(0 to 1);
    signal riu_clock_out : std_ulogic_vector(0 to 1);
    signal pll_locked : std_ulogic_vector(0 to 1);
    signal unlock_detect : std_ulogic;

    signal clk_enable : std_ulogic;
    signal raw_clk : std_ulogic;
    -- Assigning clocks
    alias ck_clk : std_ulogic is ck_clk_o;

    signal reset_sync : std_ulogic;
    signal dly_ready_in : std_ulogic;
    signal vtc_ready_in : std_ulogic;
    type reset_state_t is (
        RESET_START, RESET_RELEASE, RESET_WAIT_PLL, RESET_WAIT_DLY_RDY,
        RESET_WAIT_VTC_RDY, RESET_DONE);
    signal reset_state : reset_state_t := RESET_START;
    signal wait_counter : unsigned(5 downto 0);
    signal enable_pll_clk : std_ulogic := '0';

    -- Mark io_ck_in for SAME_CMT_COLUMN distribution so that this can drive
    -- both IO PLLs using the vertical clocking backbone.  This is equivalent to
    -- the following entry in the constraints file:
    --
    --  set_property CLOCK_DEDICATED_ROUTE SAME_CMT_COLUMN \
    --      [get_nets -of [get_pins path/to/bufg_in/O]]
    attribute CLOCK_DEDICATED_ROUTE : string;
    attribute CLOCK_DEDICATED_ROUTE of io_ck_in : signal is "SAME_CMT_COLUMN";
    attribute DONT_TOUCH : string;
    attribute DONT_TOUCH of io_ck_in : signal is "YES";

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
            CLKOUT1_DIVIDE => 8,
            CLKOUTPHY_MODE => "VCO_2X" -- 2 or 2.4 GHz on CLKOUTPHY
        ) port map (
            CLKIN => io_ck_in,
            CLKOUTPHY => phy_clk_o(i),
            CLKOUT0 => ck_clock_out(i),
            CLKOUT1 => riu_clock_out(i),
            CLKFBOUT => clkfb,
            CLKFBIN => clkfb,
            LOCKED => pll_locked(i),
            CLKOUTPHYEN => enable_pll_clk,
            PWRDWN => '0',
            RST => ck_reset_i
        );
    end generate;


    -- Controlling the master BUFG is a little tricky: we want to enable the
    -- clock when we're not in reset and the PLL is locked, but this
    -- asynchronous control signal needs to be somehow synchronised with the
    -- output clock.
    --    It looks like the safest way to do this is to take an unguarded copy
    -- of the clock and use this through a synchroniser.
    raw_bufg : BUFG port map (
        I => riu_clock_out(0),
        O => raw_clk
    );

    sync_clk_enable : entity work.sync_bit generic map (
        INITIAL => '0'
    ) port map (
        clk_i => raw_clk,
        reset_i => ck_reset_i,
        bit_i => vector_and(pll_locked),
        bit_o => clk_enable
    );

    -- Enable the global clocks once we're out of reset and the PLL is locked
    ck_bufg : BUFGCE port map (
        I => ck_clock_out(0),
        O => ck_clk,
        CE => clk_enable
    );

    riu_bufg : BUFGCE port map (
        I => riu_clock_out(0),
        O => riu_clk_o,
        CE => clk_enable
    );


    -- Synchronise reset with clock for the remaining processing
    sync_reset : entity work.sync_bit generic map (
        INITIAL => '1'
    ) port map (
        clk_i => ck_clk,
        reset_i => ck_reset_i,
        bit_i => '0',
        bit_o => reset_sync
    );

    sync_dly_ready : entity work.sync_bit port map (
        clk_i => ck_clk,
        bit_i => dly_ready_i,
        bit_o => dly_ready_in
    );

    sync_vtc_ready : entity work.sync_bit port map (
        clk_i => ck_clk,
        bit_i => vtc_ready_i,
        bit_o => vtc_ready_in
    );


    -- Generate reset sequence.  This follows the reset process documented in
    -- UG571 starting on p296 of v1.14.
    --
    -- ... still need to sort out pull ups of TBYTE_IN ... don't
    -- actually understand this ...
    process (ck_clk, reset_sync) begin
        if reset_sync then
            reset_state <= RESET_START;
            enable_control_vtc_o <= '0';
            bitslice_reset_o <= '1';
            enable_pll_clk <= '0';
        elsif rising_edge(ck_clk) then
            case reset_state is
                when RESET_START =>
                    -- Just wait one tick before we do anything.  Note that this
                    -- event will not occur until the PLL is out of reset, as
                    -- the clock is qualified by clk_enable.
                    reset_state <= RESET_RELEASE;
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
                    enable_pll_clk <= '1';
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
            end case;
        end if;
    end process;

    enable_bitslice_control_o <= to_std_ulogic(reset_state = RESET_DONE);
    ck_clk_ok_o <=
        to_std_ulogic(reset_state = RESET_DONE) and vector_and(pll_locked);

    -- Detect PLL unlock and generate single pulse on resumption of lock
    process (ck_clk, pll_locked) begin
        if not vector_and(pll_locked) then
            unlock_detect <= '1';
        elsif rising_edge(ck_clk) then
            unlock_detect <= '0';
            ck_unlock_o <= unlock_detect;
        end if;
    end process;
end;
