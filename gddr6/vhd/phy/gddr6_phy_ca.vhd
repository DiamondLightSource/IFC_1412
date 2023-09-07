-- Interfacing to CA

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.support.all;
use work.gddr6_phy_defs.all;

entity gddr6_phy_ca is
    port (
        clk_i : in std_ulogic;
        -- Internal resets for IO components
        reset_i : in std_ulogic;
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
    signal ca_in : vector_array(0 to 1)(15 downto 0);
    signal ca_out : std_ulogic_vector(15 downto 0);

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
    -- Gather all the incoming CA outputs into a single array
    -- We perform the optional address bus inversion at this point
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
            14 downto 11 => invert_bits xor ca3_in(i, ca_i(i)(3), ca3_i),
            -- Channel enable
            15 => cke_n_i
        );
    end generate;

    -- Redistribute the generated outputs as required to output pins, matching
    -- the assignments above
    io_ca_o <= ca_out(9 downto 0);
    io_cabi_n_o <= ca_out(10);
    io_ca3_o <= ca_out(14 downto 11);
    io_cke_n_o <= ca_out(15);


    -- Generate ODDR for all CA outputs
    gen_out : for i in 0 to 15 generate
        -- Need to skip entry #3
        if_ca3 : if i /= 3 generate
            oddr : ODDRE1 generic map (
                SRVAL => '1'
            ) port map (
                SR => reset_i,
                C => clk_i,
                D1 => ca_in(0)(i),
                D2 => ca_in(1)(i),
                Q => ca_out(i)
            );
        end generate;
    end generate;


    -- Register SG reset signal
    gen_resets : for i in 0 to 1 generate
        i_reset : ODDRE1 generic map (
            SRVAL => '0'
        ) port map (
            SR => reset_i,
            C => clk_i,
            D1 => sg_resets_n_i(i),
            D2 => sg_resets_n_i(i),
            Q => io_sg_resets_n_o(i)
        );
    end generate;
end;
