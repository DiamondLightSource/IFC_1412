-- Remapping of individual bitslices and controls

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_config_defs.all;

entity gddr6_phy_dq_remap is
    port (
        -- Capture clocks to bitslices
        wck_i : in std_ulogic_vector(0 to 1);

        -- Bitslice resources organised by byte and slice
        data_i : in vector_array_array(0 to 7)(0 to 11)(7 downto 0);
        data_o : out vector_array_array(0 to 7)(0 to 11)(7 downto 0);
        pad_in_o : out vector_array(0 to 7)(0 to 11);
        pad_out_i : in vector_array(0 to 7)(0 to 11);
        pad_t_out_i : in vector_array(0 to 7)(0 to 11);

        -- Remapped data organised by pin and tick
        bank_data_o : out vector_array(63 downto 0)(7 downto 0);
        bank_data_i : in vector_array(63 downto 0)(7 downto 0);
        bank_dbi_n_o : out vector_array(7 downto 0)(7 downto 0);
        bank_dbi_n_i : in vector_array(7 downto 0)(7 downto 0);
        bank_edc_o : out vector_array(7 downto 0)(7 downto 0);

        -- IO ports
        io_dq_o : out std_ulogic_vector(63 downto 0);
        io_dq_i : in std_ulogic_vector(63 downto 0);
        io_dq_t_o : out std_ulogic_vector(63 downto 0);
        io_dbi_n_o : out std_ulogic_vector(7 downto 0);
        io_dbi_n_i : in std_ulogic_vector(7 downto 0);
        io_dbi_n_t_o : out std_ulogic_vector(7 downto 0);
        io_edc_i : in std_ulogic_vector(7 downto 0)
    );
end;

architecture arch of gddr6_phy_dq_remap is
begin
    -- Use the DQ, DBI, EDC, WCK configurations to bind to the appropriate
    -- slices

    -- DQ
    gen_dq : for i in 0 to 63 generate
        constant byte : natural := CONFIG_BANK_DQ(i).byte;
        constant slice : natural := CONFIG_BANK_DQ(i).slice;
    begin
        -- IO pad binding
        pad_in_o(byte)(slice) <= io_dq_i(i);
        io_dq_t_o(i) <= pad_t_out_i(byte)(slice);
        io_dq_o(i) <= pad_out_i(byte)(slice);
        -- Data flow
        data_o(byte)(slice) <= bank_data_i(i);
        bank_data_o(i) <= data_i(byte)(slice);
    end generate;

    -- Similarly for DBI
    gen_dbi : for i in 0 to 7 generate
        constant byte : natural := CONFIG_BANK_DBI(i).byte;
        constant slice : natural := CONFIG_BANK_DBI(i).slice;
    begin
        -- IO pad binding
        pad_in_o(byte)(slice) <= io_dbi_n_i(i);
        io_dbi_n_t_o(i) <= pad_t_out_i(byte)(slice);
        io_dbi_n_o(i) <= pad_out_i(byte)(slice);
        -- Data flow
        data_o(byte)(slice) <= bank_dbi_n_i(i);
        bank_dbi_n_o(i) <= data_i(byte)(slice);
    end generate;

    -- EDC (input only)
    gen_edc : for i in 0 to 7 generate
        constant byte : natural := CONFIG_BANK_EDC(i).byte;
        constant slice : natural := CONFIG_BANK_EDC(i).slice;
    begin
        -- IO pad binding
        pad_in_o(byte)(slice) <= io_edc_i(i);
        -- Data flow
        data_o(byte)(slice) <= X"00";
        bank_edc_o(i) <= data_i(byte)(slice);
    end generate;

    -- WCK (clock only, input only)
    gen_wck : for i in 0 to 1 generate
        constant byte : natural := CONFIG_BANK_WCK(i).byte;
        constant slice : natural := CONFIG_BANK_WCK(i).slice;
    begin
        pad_in_o(byte)(slice) <= wck_i(i);
        data_o(byte)(slice) <= X"00";
    end generate;


    -- Finally fill in suitable empty markers for unused entries.  This is
    -- mostly needed to suppress simulation complaints.
    gen_bytes : for byte in 0 to 7 generate
        constant BITSLICE_WANTED : std_ulogic_vector := bitslice_wanted(byte);
    begin
        gen_slices : for slice in 0 to 11 generate
            gen_unused : if not BITSLICE_WANTED(slice) generate
                pad_in_o(byte)(slice) <= '-';
                data_o(byte)(slice) <= X"00";
            end generate;
        end generate;
    end generate;
end;
