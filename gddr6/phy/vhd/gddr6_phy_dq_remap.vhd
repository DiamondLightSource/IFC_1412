-- Remapping of individual bitslices and controls

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_phy_defs.all;

entity gddr6_phy_dq_remap is
    port (
        -- Capture clock to bitslices
        wck_i : in std_ulogic_vector(0 to 1);

        -- Bitslice resources organised by byte and slice
        enable_bitslice_vtc_o : out vector_array(0 to 7)(0 to 11);
        rx_load_o : out vector_array(0 to 7)(0 to 11);
        rx_delay_i : in vector_array_array(0 to 7)(0 to 11)(8 downto 0);
        tx_load_o : out vector_array(0 to 7)(0 to 11);
        tx_delay_i : in vector_array_array(0 to 7)(0 to 11)(8 downto 0);
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

        -- Delay interface
        delay_rx_tx_n_i : in std_ulogic;
        delay_dq_o : out vector_array(0 to 63)(8 downto 0);
        delay_dq_vtc_i : in std_ulogic_vector(0 to 63);
        delay_dq_load_i : in std_ulogic_vector(0 to 63);
        delay_dbi_o : out vector_array(0 to 7)(8 downto 0);
        delay_dbi_vtc_i : in std_ulogic_vector(0 to 7);
        delay_dbi_load_i : in std_ulogic_vector(0 to 7);
        delay_edc_o : out vector_array(0 to 7)(8 downto 0);
        delay_edc_vtc_i : in std_ulogic_vector(0 to 7);
        delay_edc_load_i : in std_ulogic_vector(0 to 7);

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
    -- Use the DQ, DBI, and EDC configurations to bind to the appropriate slices
    -- On the face of it, this intricate but very repetitive mapping process is
    -- a good candidate for abstracting into a procedure.  Alas, this doesn't
    -- come out particularly well and is just as long winded.

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
        -- Delay control
        delay_dq_o(i) <=
            rx_delay_i(byte)(slice) when delay_rx_tx_n_i else
            tx_delay_i(byte)(slice);
        enable_bitslice_vtc_o(byte)(slice) <= delay_dq_vtc_i(i);
        rx_load_o(byte)(slice) <= delay_dq_load_i(i) and delay_rx_tx_n_i;
        tx_load_o(byte)(slice) <= delay_dq_load_i(i) and not delay_rx_tx_n_i;
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
        -- Delay control
        delay_dbi_o(i) <=
            rx_delay_i(byte)(slice) when delay_rx_tx_n_i else
            tx_delay_i(byte)(slice);
        enable_bitslice_vtc_o(byte)(slice) <= delay_dbi_vtc_i(i);
        rx_load_o(byte)(slice) <= delay_dbi_load_i(i) and delay_rx_tx_n_i;
        tx_load_o(byte)(slice) <= delay_dbi_load_i(i) and not delay_rx_tx_n_i;
    end generate;

    -- And finally for EDC (this is input only, so slightly simpler)
    gen_edc : for i in 0 to 7 generate
        constant byte : natural := CONFIG_BANK_EDC(i).byte;
        constant slice : natural := CONFIG_BANK_EDC(i).slice;
    begin
        -- IO pad binding
        pad_in_o(byte)(slice) <= io_edc_i(i);
        -- Data flow
        data_o(byte)(slice) <= X"00";
        bank_edc_o(i) <= data_i(byte)(slice);
        -- Delay control
        delay_edc_o(i) <= rx_delay_i(byte)(slice);
        enable_bitslice_vtc_o(byte)(slice) <= delay_edc_vtc_i(i);
        rx_load_o(byte)(slice) <= delay_edc_load_i(i) and delay_rx_tx_n_i;
        tx_load_o(byte)(slice) <= '0';
    end generate;

    -- WCK
    gen_wck : for i in 0 to 1 generate
        constant byte : natural := CONFIG_BANK_WCK(i).byte;
        constant slice : natural := CONFIG_BANK_WCK(i).slice;
    begin
        pad_in_o(byte)(slice) <= wck_i(i);
        data_o(byte)(slice) <= X"00";
        enable_bitslice_vtc_o(byte)(slice) <= '1';
        rx_load_o(byte)(slice) <= '0';
        tx_load_o(byte)(slice) <= '0';
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
                enable_bitslice_vtc_o(byte)(slice) <= '1';
                rx_load_o(byte)(slice) <= '0';
                tx_load_o(byte)(slice) <= '0';
            end generate;
        end generate;
    end generate;
end;
