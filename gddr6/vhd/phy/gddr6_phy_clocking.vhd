-- Clock generation

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
        -- Asynchronous reset.  Must be asserted until io_ck_i is valid
        ck_reset_i : in std_ulogic;
        -- Clock in from SG12_CK
        io_ck_i : in std_ulogic;

        -- Application clock
        ck_clk_o : out std_ulogic;
        -- Special clock for delaying CA output
        ck_clk_delay_o : out std_ulogic;
        -- Dedicated clocks to bitslice outputs
        phy_clk_o : out std_ulogic_vector(0 to 1);
        -- Dedicated bitslice reset configuration clock
        riu_clk_o : out std_ulogic;

        -- Set to enable the PLL PHY clocks
        enable_pll_phy_i : in std_ulogic;

        -- Control over phase shift of ck_clk_delay_o
        phase_direction_i : in std_ulogic;
        phase_step_i : in std_ulogic;
        phase_step_ack_o : out std_ulogic;
        -- Current phase offset in range 0 to 223 (4 x 56)
        phase_o : out unsigned(7 downto 0);

        -- Set when PLL is locked, synchronous to CK clock
        pll_locked_o : out std_ulogic;
        -- Set when MMCM is locked, asynchronous.  Used to detect CK dropout
        mmcm_locked_o : out std_ulogic
    );
end;

architecture arch of gddr6_phy_clocking is
    -- Input clock and MMCM
    signal io_ck_in : std_ulogic;
    signal mmcm_clkfbout : std_ulogic;
    signal mmcm_clkfbin : std_ulogic;
    signal ck_clk_out : std_ulogic;
    signal riu_clk_out : std_ulogic;
    signal ck_clk_delay_out : std_ulogic;
    signal mmcm_locked : std_ulogic;

    -- PLL
    signal pll_locked : std_ulogic_vector(0 to 1);

    -- Clock enable control and output clocks
    signal clk_enable : std_ulogic;
    signal raw_clk : std_ulogic;
    -- Assigning clocks
    alias ck_clk : std_ulogic is ck_clk_o;
    alias riu_clk : std_ulogic is riu_clk_o;

    -- Clock phase control
    signal phase_direction : std_ulogic;
    signal phase_step : std_ulogic;
    signal phase_step_ack : std_ulogic;
    -- As documented in ug572 a single phase increment steps the phase of the
    -- target output clock by one part in 56 (this is quite a strange number,
    -- being 1/7 of 45 degrees), which corresponds to 1/4 of this amount (or
    -- just over 1.6 degrees) for the output clock at 4x VCO frequency.  Hence
    -- the valid range of phases is 0 to 233 (=4*56-1).
    constant MAX_PHASE : unsigned(7 downto 0) := to_unsigned(223, 8);
    signal phase : unsigned(7 downto 0) := (others => '0');

begin
    bufg_in : BUFG port map (
        I => io_ck_i,
        O => io_ck_in
    );


    -- Bring clock phase adjustments over to the io_ck_in clock domain
    write_phase : entity work.cross_clocks_write port map (
        clk_in_i => ck_clk,
        strobe_i => phase_step_i,
        ack_o => phase_step_ack_o,
        data_i(0) => phase_direction_i,

        clk_out_i => io_ck_in,
        strobe_o => phase_step,
        ack_i => phase_step_ack,
        data_o(0) => phase_direction
    );

    -- Keep track of the phase as it is adjusted.
    process (ck_reset_i, ck_clk) begin
        if ck_reset_i then
            phase <= (others => '0');
        elsif rising_edge(ck_clk) then
            if phase_step_i then
                case phase_direction_i is
                    when '0' =>     -- Decrement phase
                        if phase > 0 then
                            phase <= phase - 1;
                        else
                            phase <= MAX_PHASE;
                        end if;
                    when '1' =>     -- Increment phase
                        if phase < MAX_PHASE then
                            phase <= phase + 1;
                        else
                            phase <= (others => '0');
                        end if;
                    when others =>
                end case;
            end if;
        end if;
    end process;
    phase_o <= phase;


    -- We need to run ck_clk in phase with CK; apparently this cannot be done
    -- with a PLL and so use an MMCM to generate our clocks.  We'll still need
    -- PLLs for the high speed bitslice output clocks.
    --    The CA output clock (ck_clk_delay_o) runs at a configurable phase
    -- offset relative to the original CK clock: this is required so that we can
    -- reliably align our CA commands with the SG CK clock.
    --
    -- The name of this instance is used in sgram.tcl to apply special clocking
    -- constraints to this MMCM
    sg_dram_mmcm : MMCME3_ADV generic map (
        CLKFBOUT_MULT_F => 4.0,     -- Input clock at 250 MHz, run VCO at 1GHz
        CLKIN1_PERIOD => 1000.0 / CK_FREQUENCY,
        CLKOUT0_DIVIDE_F => 4.0,    -- ck_clk_delay for ODDR clocking
        CLKOUT0_USE_FINE_PS => "TRUE",
        CLKOUT1_DIVIDE => 4,        -- ck_clk at 250 MHz
        CLKOUT2_DIVIDE => 8         -- riu_clk at 125 MHz
    ) port map (
        CLKIN1 => io_ck_in,
        CLKOUT0 => ck_clk_delay_out,
        CLKOUT1 => ck_clk_out,
        CLKOUT2 => riu_clk_out,
        CLKFBOUT => mmcm_clkfbout,
        CLKFBIN => mmcm_clkfbin,
        LOCKED => mmcm_locked,
        RST => ck_reset_i,
        -- Fine phase control
        PSCLK => io_ck_in,
        PSINCDEC => phase_direction,
        PSEN => phase_step,
        PSDONE => phase_step_ack,
        -- Unused ports
        CLKIN2 => '0',
        CLKINSEL => '1',
        CDDCREQ => '0',
        DCLK => '0',
        DADDR => (others => '0'),
        DI => (others => '0'),
        DEN => '0',
        DWE => '0',
        PWRDWN => '0'
    );
    mmcm_locked_o <= mmcm_locked;

    bufg_clkfb : BUFG port map (
        I => mmcm_clkfbout,
        O => mmcm_clkfbin
    );


    -- Generate the high speed bitslice output clocks
    -- The clock generation process for multiple IO banks for the bitslice PHY
    -- clock is frustratingly brittle.  This is poorly documented on pages 298
    -- and 299 of UG571 (v1.14).  The gist of the advice appears to be that, as
    -- followed here, the application clock (ck_clk here) must be generated by
    -- an MMCM and used as CLKIN for both PLLs generating the PHY clock.
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
            CLKIN => ck_clk,
            CLKOUTPHY => phy_clk_o(i),
            CLKFBOUT => clkfb,
            CLKFBIN => clkfb,
            LOCKED => locked,
            CLKOUTPHYEN => enable_pll_phy_i,
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
    pll_locked_o <= vector_and(pll_locked);


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
end;
