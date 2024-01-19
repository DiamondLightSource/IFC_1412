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
        -- Special clock for delaying CA output
        ck_clk_delay_o : out std_ulogic;

        -- Resets and clock status
        ck_reset_i : in std_ulogic;
        ck_clk_ok_o : out std_ulogic;
        ck_unlock_o : out std_ulogic := '0';

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
    -- Advance CK clock to help align the CA output eye with the centre of the
    -- CK clock
    constant CA_PHASE_SHIFT : real := -90.0;

    signal io_ck_in : std_ulogic;
    signal mmcm_clkfbout : std_ulogic;
    signal mmcm_clkfbin : std_ulogic;
    signal ck_clk_out : std_ulogic;
    signal ck_clk_pllin : std_ulogic;
    signal riu_clk_out : std_ulogic;
    signal ck_clk_delay_out : std_ulogic;
    signal mmcm_locked : std_ulogic;
    signal pll_locked : std_ulogic_vector(0 to 1);
    signal unlock_detect : std_ulogic;

    signal clk_enable : std_ulogic;
    signal raw_clk : std_ulogic;
    -- Assigning clocks
    alias ck_clk : std_ulogic is ck_clk_o;
    alias riu_clk : std_ulogic is riu_clk_o;

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
    bufg_in : BUFG port map (
        I => io_ck_i,
        O => io_ck_in
    );

    bufg_clkfb : BUFG port map (
        I => mmcm_clkfbout,
        O => mmcm_clkfbin
    );

    -- We need to run ck_clk in phase with CK; apparently this cannot be done
    -- with a PLL and so use an MMCM to generate our clocks.  We'll still need
    -- PLLs for the high speed bitslice output clocks.
    mmcm : MMCME3_BASE generic map (
        CLKFBOUT_MULT_F => 4.0,     -- Input clock at 250 MHz, run VCO at 1GHz
        CLKIN1_PERIOD => 1000.0 / CK_FREQUENCY,
        CLKOUT0_DIVIDE_F => 4.0,    -- ck_clk at 250 MHz
        CLKOUT1_DIVIDE => 8,        -- riu_clk at 125 MHz
        CLKOUT2_DIVIDE => 4,        -- ck_clk_delay for ODDR clocking
        CLKOUT2_PHASE => CA_PHASE_SHIFT
    ) port map (
        CLKIN1 => io_ck_in,
        CLKOUT0 => ck_clk_out,
        CLKOUT1 => riu_clk_out,
        CLKOUT2 => ck_clk_delay_out,
        CLKFBOUT => mmcm_clkfbout,
        CLKFBIN => mmcm_clkfbin,
        LOCKED => mmcm_locked,
        PWRDWN => '0',
        RST => ck_reset_i
    );


    bufg_pll_ckin : BUFG port map (
        I => ck_clk_out,
        O => ck_clk_pllin
    );

    -- Generate the high speed bitslice output clocks
    gen_plls : for i in 0 to 1 generate
        signal clkfb : std_ulogic;
        signal locked : std_ulogic;
    begin
        -- Input clock is 250, the PLL runs at 1 GHz
        pll : PLLE3_BASE generic map (
            CLKFBOUT_MULT => 4,         -- Input at 250 MHz, VCO at 1 GHz
            CLKIN_PERIOD => 1000.0 / CK_FREQUENCY,
            CLKOUTPHY_MODE => "VCO_2X"  -- 2 GHz on CLKOUTPHY
        ) port map (
            CLKIN => ck_clk_pllin,
            CLKOUTPHY => phy_clk_o(i),
            CLKFBOUT => clkfb,
            CLKFBIN => clkfb,
            LOCKED => locked,
            CLKOUTPHYEN => enable_pll_clk,
            PWRDWN => '0',
            RST => ck_reset_i
        );

        sync : entity work.sync_bit port map (
            clk_i => riu_clk,
            reset_i => ck_reset_i,
            bit_i => locked,
            bit_o => pll_locked(i)
        );
    end generate;


    -- Controlling the master BUFG is a little tricky: we want to enable the
    -- clock when we're not in reset and the PLL is locked, but this
    -- asynchronous control signal needs to be somehow synchronised with the
    -- output clock.
    --    It looks like the safest way to do this is to take an unguarded copy
    -- of the clock and use this through a synchroniser.
    raw_bufg : BUFG port map (
        I => riu_clk_out,
        O => raw_clk
    );

    sync_clk_enable : entity work.sync_bit generic map (
        INITIAL => '0'
    ) port map (
        clk_i => raw_clk,
        reset_i => ck_reset_i,
        bit_i => mmcm_locked,
        bit_o => clk_enable
    );

    -- Enable the global clocks once we're out of reset and the PLL is locked
    ck_bufg : BUFGCE port map (
        I => ck_clk_out,
        O => ck_clk,
        CE => clk_enable
    );

    riu_bufg : BUFGCE port map (
        I => riu_clk_out,
        O => riu_clk,
        CE => clk_enable
    );

    -- This clock is not qualified, doesn't really need to be, there is no
    -- persistent state downstream, and meeting timing here is too challenging!
    ck_delay_bufg : BUFG port map (
        I => ck_clk_delay_out,
        O => ck_clk_delay_o
    );


    -- Synchronise reset with clock for the remaining processing
    sync_reset : entity work.sync_bit generic map (
        INITIAL => '1'
    ) port map (
        clk_i => riu_clk,
        reset_i => ck_reset_i,
        bit_i => '0',
        bit_o => reset_sync
    );

    sync_dly_ready : entity work.sync_bit port map (
        clk_i => riu_clk,
        bit_i => dly_ready_i,
        bit_o => dly_ready_in
    );

    sync_vtc_ready : entity work.sync_bit port map (
        clk_i => riu_clk,
        bit_i => vtc_ready_i,
        bit_o => vtc_ready_in
    );


    -- Generate reset sequence.  This follows the reset process documented in
    -- UG571 starting on p296 of v1.14.
    process (riu_clk, reset_sync) begin
        if reset_sync then
            reset_state <= RESET_START;
            enable_control_vtc_o <= '0';
            bitslice_reset_o <= '1';
            enable_pll_clk <= '0';
            enable_bitslice_control_o <= '0';
            wait_counter <= 6X"0F";
        elsif rising_edge(riu_clk) then
            case reset_state is
                when RESET_START =>
                    -- Wait a few ticks before we do anything.  Note that this
                    -- event will not occur until the MMCM is out of reset, as
                    -- the clock is qualified by clk_enable.
                    if wait_counter > 0 then
                        wait_counter <= wait_counter - 1;
                    elsif vector_and(pll_locked) then
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
                    enable_bitslice_control_o <= '1';
            end case;
        end if;
    end process;

    -- Detect PLL unlock and generate single pulse on resumption of lock
    process (ck_clk, mmcm_locked) begin
        if not mmcm_locked then
            unlock_detect <= '1';
        elsif rising_edge(ck_clk) then
            unlock_detect <= '0';
            ck_unlock_o <= unlock_detect;
        end if;
    end process;

    -- Ensure we report CK not ok if we lose valid CK at any time
    ck_clk_ok_o <= to_std_ulogic(reset_state = RESET_DONE) and mmcm_locked;
end;
