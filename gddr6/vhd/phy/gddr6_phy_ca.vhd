-- Interfacing to CA

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.support.all;
use work.gddr6_phy_defs.all;

entity gddr6_phy_ca is
    generic (
        REFCLK_FREQUENCY : real
    );
    port (
        ck_clk_i : in std_ulogic;
        ck_clk_delay_i : in std_ulogic;

        -- Internal resets for IO components
        bitslice_reset_i : in std_ulogic;
        -- Individual resets for GDDR6 devices
        sg_resets_n_i : in std_ulogic_vector(0 to 1);

        -- Command interface, first word then second word.  Bit 3 in the second
        -- word can be overridden by ca3_i if required.
        ca_i : in vector_array(0 to 1)(9 downto 0);
        -- The second tick of bit 3 can be overridded by or-ing in ca3_i so that
        -- this can act as a chip select
        ca3_i : in std_ulogic_vector(0 to 3);
        cke_n_i : in std_ulogic;
        enable_cabi_i : in std_ulogic;

        -- Pins driven out
        io_sg_resets_n_o : out std_ulogic_vector(0 to 1);
        io_ca_o : out std_ulogic_vector(9 downto 0);   -- Pin 3 is ignored
        io_ca3_o : out std_ulogic_vector(0 to 3);      -- 1A 1B 2A 2B
        io_cabi_n_o : out std_ulogic;
        io_cke_n_o : out std_ulogic
    );
end;

architecture arch of gddr6_phy_ca is
    -- So that the outputs can be uniformly generated gather
    -- CA, CA3, CABI into a single 15 element vector
    signal ca_in : vector_array(0 to 1)(14 downto 0);
    signal ca_out : std_ulogic_vector(14 downto 0);
    -- Output signals registered for output
    signal d1 : std_ulogic_vector(14 downto 0) := (others => '1');
    signal d2 : std_ulogic_vector(14 downto 0);
    -- CKEn needs to straddle two ticks to align its centre with the rising edge
    signal cke_n_in : std_ulogic := '0';

    -- Account for the variable phase from ck_clk_i to ck_clk_delay_i
    attribute max_delay_from : string;
    attribute max_delay_from of d1 : signal is "1.5";
    attribute max_delay_from of d2 : signal is "1.5";
    attribute KEEP : string;
    attribute KEEP of d1 : signal is "TRUE";
    attribute KEEP of d2 : signal is "TRUE";


    -- Special treatment of CA3: in the second tick of a command CA3 can be
    -- used as a chip select.
    function ca3_in(
        tick : natural; ca : std_ulogic; ca3 : std_ulogic_vector(0 to 3))
    return std_ulogic_vector is
    begin
        if tick = 0 then
            -- Ignore ca3 array in tick 0
            return (0 to 3 => ca);
        else
            -- Allow ca3 to act as chip select when ca_i(1)(3) is zero
            return ca3 or ca;
        end if;
    end;

begin
    -- Gather all the incoming CA outputs into a single array, rising edge part
    -- of command in ca_i(0) and falling edge in ca_i(1).
    -- Also perform optional address bus inversion at this point
    gen_ca_in : for i in 0 to 1 generate
        signal invert_bits : std_ulogic;
    begin
        invert_bits <= enable_cabi_i and compute_bus_inversion(ca_i(i));
        ca_in(i) <= (
            -- Outputs to CAL
            2 downto 0 => invert_bits xor ca_i(i)(2 downto 0),
            3 => '-',
            -- Outputs to CAH
            9 downto 4 => invert_bits xor ca_i(i)(9 downto 4),
            -- Optional bus inversion
            10 => not invert_bits,
            -- Outputs to CA3 per channel and device
            14 downto 11 => invert_bits xor ca3_in(i, ca_i(i)(3), ca3_i)
        );
    end generate;

    process (ck_clk_i) begin
        if rising_edge(ck_clk_i) then
            -- Register CA data before sending to avoid timing problems in
            -- transition to shifted output clock
            d1 <= ca_in(0);
            d2 <= ca_in(1);
            -- Remember CKE_n for output shaping
            cke_n_in <= cke_n_i;
        end if;
    end process;

    -- Generate ODDR for all CA outputs.  We use the delayed clock to generate
    -- the output data so that we can align the centre of the CA data valid
    -- eye with the centre of CK.  This is much easier than using an ODELAY!
    gen_out : for i in 0 to 14 generate
        -- Need to skip entry #3
        if_ca3 : if i = 3 generate
            ca_out(i) <= '0';
        else generate
            oddr : ODDRE1 generic map (
                SRVAL => '1'
            ) port map (
                SR => bitslice_reset_i,
                C => ck_clk_delay_i,
                D1 => d1(i),
                D2 => d2(i),
                Q => ca_out(i)
            );
        end generate;
    end generate;

    -- Redistribute the generated outputs as required to output pins, matching
    -- the assignments above
    io_ca_o <= ca_out(9 downto 0);
    io_cabi_n_o <= ca_out(10);
    io_ca3_o <= ca_out(14 downto 11);


    -- Special treatment for CKE_n: this is changed on the falling edge of CK
    -- and will be sampled on the rising edge.  We therefore assign the new
    -- value to D2 and the value from the last tick to D1.
    cken_oddr : ODDRE1 generic map (
        SRVAL => '1'
    ) port map (
        SR => bitslice_reset_i,
        C => ck_clk_i,
        D1 => cke_n_in,
        D2 => cke_n_i,
        Q => io_cke_n_o
    );

    -- Register SG reset signal
    gen_resets : for i in 0 to 1 generate
        i_reset : ODDRE1 generic map (
            SRVAL => '0'
        ) port map (
            SR => bitslice_reset_i,
            C => ck_clk_i,
            D1 => sg_resets_n_i(i),
            D2 => sg_resets_n_i(i),
            Q => io_sg_resets_n_o(i)
        );
    end generate;
end;
