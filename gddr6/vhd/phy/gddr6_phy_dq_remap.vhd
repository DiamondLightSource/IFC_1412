-- Remapping of individual bitslices and controls

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_config_defs.all;
use work.gddr6_phy_defs.all;

entity gddr6_phy_dq_remap is
    port (
        -- Capture clocks to bitslices
        wck_i : in std_ulogic_vector(0 to 1);

        -- Bitslice resources organised by byte and slice
        slice_data_i : in vector_array_array(0 to 7)(0 to 11)(7 downto 0);
        slice_data_o : out vector_array_array(0 to 7)(0 to 11)(7 downto 0);
        slice_pad_in_o : out vector_array(0 to 7)(0 to 11);
        slice_pad_out_i : in vector_array(0 to 7)(0 to 11);
        slice_pad_t_out_i : in vector_array(0 to 7)(0 to 11);
        -- VTC controls
        slice_enable_tri_vtc_o : out vector_array(0 to 7)(0 to 1);
        slice_enable_rx_vtc_o : out vector_array(0 to 7)(0 to 11);
        slice_enable_tx_vtc_o : out vector_array(0 to 7)(0 to 11);
        -- Delay controls
        slice_rx_delay_ce_o : out vector_array(0 to 7)(0 to 11);
        slice_tx_delay_ce_o : out vector_array(0 to 7)(0 to 11);
        -- Delay readbacks
        slice_rx_delay_i : in vector_array_array(0 to 7)(0 to 11)(8 downto 0);
        slice_tx_delay_i : in vector_array_array(0 to 7)(0 to 11)(8 downto 0);

        -- Remapped data organised by pin and tick
        bank_data_o : out vector_array(63 downto 0)(7 downto 0);
        bank_data_i : in vector_array(63 downto 0)(7 downto 0);
        bank_dbi_n_o : out vector_array(7 downto 0)(7 downto 0);
        bank_dbi_n_i : in vector_array(7 downto 0)(7 downto 0);
        bank_edc_o : out vector_array(7 downto 0)(7 downto 0);
        bank_edc_i : in std_ulogic;

        -- Delay controls and readbacks
        delay_control_i : in bitslice_delay_control_t;
        delay_readbacks_o : out bitslice_delay_readbacks_t;

        -- IO ports
        io_dq_o : out std_ulogic_vector(63 downto 0);
        io_dq_i : in std_ulogic_vector(63 downto 0);
        io_dq_t_o : out std_ulogic_vector(63 downto 0);
        io_dbi_n_o : out std_ulogic_vector(7 downto 0);
        io_dbi_n_i : in std_ulogic_vector(7 downto 0);
        io_dbi_n_t_o : out std_ulogic_vector(7 downto 0);
        io_edc_i : in std_ulogic_vector(7 downto 0);
        io_edc_o : out std_ulogic_vector(7 downto 0);
        io_edc_t_o : out std_ulogic_vector(7 downto 0);

        -- Patch inputs
        bitslice_patch_i : in std_ulogic_vector
    );
end;

architecture arch of gddr6_phy_dq_remap is
    signal dq_rx_delay : vector_array(63 downto 0)(8 downto 0);
    signal dq_tx_delay : vector_array(63 downto 0)(8 downto 0);
    signal dbi_rx_delay : vector_array(7 downto 0)(8 downto 0);
    signal dbi_tx_delay : vector_array(7 downto 0)(8 downto 0);
    signal edc_rx_delay : vector_array(7 downto 0)(8 downto 0);

begin
    -- Use the CONFIG_BANK configurations to bind to the appropriate slices

    -- DQ
    gen_dq : for i in 0 to 63 generate
        constant byte : natural := CONFIG_BANK_DQ(i).byte;
        constant slice : natural := CONFIG_BANK_DQ(i).slice;
    begin
        -- IO pad binding
        slice_pad_in_o(byte)(slice) <= io_dq_i(i);
        io_dq_t_o(i) <= slice_pad_t_out_i(byte)(slice);
        io_dq_o(i) <= slice_pad_out_i(byte)(slice);
        -- Data flow
        slice_data_o(byte)(slice) <= bank_data_i(i);
        bank_data_o(i) <= slice_data_i(byte)(slice);
        -- Delay control and readback
        slice_rx_delay_ce_o(byte)(slice) <= delay_control_i.dq_rx_ce(i);
        slice_tx_delay_ce_o(byte)(slice) <= delay_control_i.dq_tx_ce(i);
        dq_rx_delay(i) <= slice_rx_delay_i(byte)(slice);
        dq_tx_delay(i) <= slice_tx_delay_i(byte)(slice);
        -- VTC control
        slice_enable_rx_vtc_o(byte)(slice) <= delay_control_i.dq_rx_vtc(i);
        slice_enable_tx_vtc_o(byte)(slice) <= delay_control_i.dq_tx_vtc(i);
    end generate;

    -- DBI
    gen_dbi : for i in 0 to 7 generate
        constant byte : natural := CONFIG_BANK_DBI(i).byte;
        constant slice : natural := CONFIG_BANK_DBI(i).slice;
    begin
        -- IO pad binding
        slice_pad_in_o(byte)(slice) <= io_dbi_n_i(i);
        io_dbi_n_t_o(i) <= slice_pad_t_out_i(byte)(slice);
        io_dbi_n_o(i) <= slice_pad_out_i(byte)(slice);
        -- Data flow
        slice_data_o(byte)(slice) <= bank_dbi_n_i(i);
        bank_dbi_n_o(i) <= slice_data_i(byte)(slice);
        -- Delay control and readback
        slice_rx_delay_ce_o(byte)(slice) <= delay_control_i.dbi_rx_ce(i);
        slice_tx_delay_ce_o(byte)(slice) <= delay_control_i.dbi_tx_ce(i);
        dbi_rx_delay(i) <= slice_rx_delay_i(byte)(slice);
        dbi_tx_delay(i) <= slice_tx_delay_i(byte)(slice);
        -- VTC control
        slice_enable_rx_vtc_o(byte)(slice) <= delay_control_i.dbi_rx_vtc(i);
        slice_enable_tx_vtc_o(byte)(slice) <= delay_control_i.dbi_tx_vtc(i);
    end generate;

    -- EDC (input only)
    gen_edc : for i in 0 to 7 generate
        constant byte : natural := CONFIG_BANK_EDC(i).byte;
        constant slice : natural := CONFIG_BANK_EDC(i).slice;
    begin
        -- IO pad binding
        slice_pad_in_o(byte)(slice) <= io_edc_i(i);
        io_edc_t_o(i) <= slice_pad_t_out_i(byte)(slice);
        io_edc_o(i) <= slice_pad_out_i(byte)(slice);
        -- Data flow
        slice_data_o(byte)(slice) <= (others => bank_edc_i);
        bank_edc_o(i) <= slice_data_i(byte)(slice);
        -- Delay control and readback
        slice_rx_delay_ce_o(byte)(slice) <= delay_control_i.edc_rx_ce(i);
        slice_tx_delay_ce_o(byte)(slice) <= '0';
        edc_rx_delay(i) <= slice_rx_delay_i(byte)(slice);
        -- VTC control
        slice_enable_rx_vtc_o(byte)(slice) <= delay_control_i.edc_rx_vtc(i);
        slice_enable_tx_vtc_o(byte)(slice) <= '1';
    end generate;

    -- WCK (clock only, input only)
    gen_wck : for i in 0 to 1 generate
        constant byte : natural := CONFIG_BANK_WCK(i).byte;
        constant slice : natural := CONFIG_BANK_WCK(i).slice;
    begin
        slice_pad_in_o(byte)(slice) <= wck_i(i);
        slice_data_o(byte)(slice) <= X"00";
        slice_rx_delay_ce_o(byte)(slice) <= '0';
        slice_tx_delay_ce_o(byte)(slice) <= '0';
        slice_enable_rx_vtc_o(byte)(slice) <= '1';
        slice_enable_tx_vtc_o(byte)(slice) <= '1';
    end generate;

    -- PATCH: link component signal to patch bitslice
    get_patch : for i in CONFIG_BANK_PATCH'RANGE generate
        constant byte : natural := CONFIG_BANK_PATCH(i).byte;
        constant slice : natural := CONFIG_BANK_PATCH(i).slice;
    begin
        slice_pad_in_o(byte)(slice) <= bitslice_patch_i(i);
        slice_data_o(byte)(slice) <= X"00";
        slice_rx_delay_ce_o(byte)(slice) <= '0';
        slice_tx_delay_ce_o(byte)(slice) <= '0';
        slice_enable_rx_vtc_o(byte)(slice) <= '1';
        slice_enable_tx_vtc_o(byte)(slice) <= '1';
    end generate;

    -- Finally fill in suitable empty markers for unused entries.  This is
    -- mostly needed to suppress simulation complaints.
    gen_bytes : for byte in 0 to 7 generate
        constant BITSLICE_WANTED : std_ulogic_vector := bitslice_wanted(byte);
    begin
        gen_slices : for slice in 0 to 11 generate
            gen_unused : if not BITSLICE_WANTED(slice) generate
                slice_pad_in_o(byte)(slice) <= '-';
                slice_data_o(byte)(slice) <= X"00";
                slice_rx_delay_ce_o(byte)(slice) <= '0';
                slice_tx_delay_ce_o(byte)(slice) <= '0';
                slice_enable_rx_vtc_o(byte)(slice) <= '1';
                slice_enable_tx_vtc_o(byte)(slice) <= '1';
            end generate;
        end generate;
    end generate;

    -- TRI control not supported
    slice_enable_tri_vtc_o <= (others => (others => '1'));

    delay_readbacks_o <= (
        dq_rx_delay => dq_rx_delay,
        dq_tx_delay => dq_tx_delay,
        dbi_rx_delay => dbi_rx_delay,
        dbi_tx_delay => dbi_tx_delay,
        edc_rx_delay => edc_rx_delay
    );
end;
