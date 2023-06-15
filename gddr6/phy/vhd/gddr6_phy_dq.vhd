-- Bitslice instantiation for a single IO bank

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_phy_defs.all;

entity gddr6_phy_dq is
    port (
        -- Clocks
        pll_clk_i : in std_ulogic_vector(0 to 1);
        reg_clk_i : in std_ulogic;
        wck_i : in std_ulogic_vector(0 to 1);

        -- Resets and control
        reset_i : in std_ulogic;
        dly_ready_o : out std_ulogic;
        vtc_ready_o : out std_ulogic;
        fifo_empty_o : out std_ulogic;
        fifo_enable_i : in std_ulogic;
        enable_control_vtc_i : in std_ulogic;

        -- Data interface, all values for a single CA tick
        data_o : out std_ulogic_vector(511 downto 0);
        data_i : in std_ulogic_vector(511 downto 0);
        edc_o : out std_ulogic_vector(63 downto 0);
        dq_t_i : in std_ulogic;
        enable_dbi_i : in std_ulogic;

        -- Delay Control
        -- The entries are multiplexed into 64+8+8+16 = 96 bits with the
        -- following assignments:
        --      15:0    DQ 1A   )
        --      31:16   DQ 1B   ) 64 bits
        --      47:32   DQ 2A   )
        --      63:48   DQ 2B   )
        --      71:64   DBI     8 bits, one per byte
        --      79:72   EDC     8 bits, one per byte
        --      95:80   TRI     16, one per nibble
        delay_i : in std_ulogic_vector(8 downto 0);
        delay_rx_tx_n_i : in std_ulogic;                    -- RX or TX*
        enable_vtc_i : in std_ulogic_vector(0 to 95);
        load_delay_i : in std_ulogic_vector(0 to 95);
        delay_o : out vector_array(0 to 95)(8 downto 0);

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

architecture arch of gddr6_phy_dq is
    -- Clock distribution definitions.  The RX clock arrives on bit 0 of byte 1
    -- and is distributed vertically 1 => 2 => 3 (CLK_TO_NORTH) and 1 => 0
    -- (CLK_TO_SOUTH).  These constants guide the plumbing of individual bytes.
    constant MAP_CLK_FROM_PIN : boolean_array := (false, true, false, false);
    constant MAP_CLK_TO_NORTH : boolean_array := (false, true, true, false);
    constant MAP_CLK_TO_SOUTH : boolean_array := (false, true, false, false);

    -- RX clocking distribution network
    signal clk_from_ext : std_ulogic_vector(0 to 7);
    signal clk_to_north : std_ulogic_vector(0 to 7);
    signal clk_to_south : std_ulogic_vector(0 to 7);

    -- Status signals from individual bytes
    signal fifo_empty : std_ulogic_vector(0 to 7);
    signal dly_ready : std_ulogic_vector(0 to 7);
    signal vtc_ready : std_ulogic_vector(0 to 7);

    -- Arrays of bitslice resources ready for mapping
    signal enable_bitslice_vtc : vector_array(0 to 7)(0 to 11);
    signal rx_load_in : vector_array(0 to 7)(0 to 11);
    signal rx_delay_out : vector_array_array(0 to 7)(0 to 11)(8 downto 0);
    signal tx_load_in : vector_array(0 to 7)(0 to 11);
    signal tx_delay_out : vector_array_array(0 to 7)(0 to 11)(8 downto 0);
    signal data_out : vector_array_array(0 to 7)(0 to 11)(7 downto 0);
    signal data_in : vector_array_array(0 to 7)(0 to 11)(7 downto 0);
    signal pad_in_in : vector_array(0 to 7)(0 to 11);
    signal pad_out_out : vector_array(0 to 7)(0 to 11);
    signal pad_t_out_out : vector_array(0 to 7)(0 to 11);

    -- Map for delays
    signal delay_dq_out : vector_array(0 to 63)(8 downto 0); -- DQ (32)
    signal delay_dq_vtc_in : std_ulogic_vector(0 to 63);
    signal delay_dq_load_in : std_ulogic_vector(0 to 63);
    signal delay_dbi_out : vector_array(0 to 7)(8 downto 0); -- DBI (4)
    signal delay_dbi_vtc_in : std_ulogic_vector(0 to 7);
    signal delay_dbi_load_in : std_ulogic_vector(0 to 7);
    signal delay_edc_out : vector_array(0 to 7)(8 downto 0); -- EDC (4)
    signal delay_edc_vtc_in : std_ulogic_vector(0 to 7);
    signal delay_edc_load_in : std_ulogic_vector(0 to 7);
    signal delay_tri_out : vector_array(0 to 15)(8 downto 0); -- TRI (8)
    signal delay_tri_vtc_in : std_ulogic_vector(0 to 15);
    signal delay_tri_load_in : std_ulogic_vector(0 to 15);

    -- Raw data organised by pin and tick
    signal bank_data_out : vector_array(63 downto 0)(7 downto 0);
    signal bank_data_in : vector_array(63 downto 0)(7 downto 0);
    signal bank_dbi_n_out : vector_array(7 downto 0)(7 downto 0);
    signal bank_dbi_n_in : vector_array(7 downto 0)(7 downto 0);
    signal bank_edc_in : vector_array(7 downto 0)(7 downto 0);

    -- Decode ranges for delay groups above
    subtype DELAY_DQ_RANGE is natural range 0 to 63;
    subtype DELAY_DBI_RANGE is natural range 64 to 71;
    subtype DELAY_EDC_RANGE is natural range 72 to 79;
    subtype DELAY_TRI_RANGE is natural range 80 to 95;


    -- Concatentate  pin configurations for the two IO banks by remapping all
    -- the byte numbers in the second bank by adding 4.  This allows both IO
    -- banks to be generated in one step.
    function concat_configs(
        config1 : pin_config_array_t; config2 : pin_config_array_t)
        return pin_config_array_t
    is
        constant count : natural := config1'LENGTH;
        variable result : pin_config_array_t(0 to 2*count-1);
    begin
        result(0 to count-1) := config1;
        result(count to 2*count-1) := config2;
        for i in 0 to count-1 loop
            result(count + i).byte := config2(i).byte + 4;
        end loop;
        return result;
    end;

    -- Concatenate pin configurations for both IO banks.
    constant CONFIG_BANK_DQ : pin_config_array_t
        := concat_configs(CONFIG_BANK1_DQ, CONFIG_BANK2_DQ);
    constant CONFIG_BANK_DBI : pin_config_array_t
        := concat_configs(CONFIG_BANK1_DBI, CONFIG_BANK2_DBI);
    constant CONFIG_BANK_EDC : pin_config_array_t
        := concat_configs(CONFIG_BANK1_EDC, CONFIG_BANK2_EDC);

    -- Computes which slices are wanted from the given configuration for the
    -- specified byte
    function bitslice_wanted(byte : natural; config : pin_config_array_t)
        return std_ulogic_vector
    is
        variable result : std_ulogic_vector(0 to 11) := (others => '0');
    begin
        for i in config'RANGE loop
            if config(i).byte = byte then
                result(config(i).slice) := '1';
            end if;
        end loop;
        return result;
    end;

begin
    -- Generate 4 IO bytes in each of the two IO banks
    gen_bytes : for i in 0 to 7 generate
        -- Selector for nibble specific outputs
        subtype NIBBLE_SUBRANGE is natural range 2*i to 2*i+1;
    begin
        byte : entity work.gddr6_phy_byte generic map (
            REFCLK_FREQUENCY => REFCLK_FREQUENCY,
            BITSLICE_WANTED =>
                bitslice_wanted(i, CONFIG_BANK_DQ) or
                bitslice_wanted(i, CONFIG_BANK_DBI) or
                bitslice_wanted(i, CONFIG_BANK_EDC),
            CLK_FROM_PIN => MAP_CLK_FROM_PIN(i mod 4),
            CLK_TO_NORTH => MAP_CLK_TO_NORTH(i mod 4),
            CLK_TO_SOUTH => MAP_CLK_TO_SOUTH(i mod 4)
        ) port map (
            pll_clk_i => pll_clk_i(i / 4),
            fifo_rd_clk_i => reg_clk_i,
            reg_clk_i => reg_clk_i,

            fifo_empty_o => fifo_empty(i),
            fifo_enable_i => fifo_enable_i,

            reset_i => reset_i,
            enable_control_vtc_i => enable_control_vtc_i,
            enable_tri_vtc_i => delay_tri_vtc_in(NIBBLE_SUBRANGE),
            enable_bitslice_vtc_i => enable_bitslice_vtc(i),
            dly_ready_o => dly_ready(i),
            vtc_ready_o => vtc_ready(i),

            rx_load_i => rx_load_in(i),
            rx_delay_i => delay_i,
            rx_delay_o => rx_delay_out(i),
            tx_load_i => tx_load_in(i),
            tx_delay_i => delay_i,
            tx_delay_o => tx_delay_out(i),
            tri_load_i =>
                delay_tri_load_in(NIBBLE_SUBRANGE) and not delay_rx_tx_n_i,
            tri_delay_i => delay_i,
            tri_delay_o => delay_tri_out(NIBBLE_SUBRANGE),

            data_o => data_out(i),
            data_i => data_in(i),
            tbyte_i => (others => dq_t_i),

            pad_in_i => pad_in_in(i),
            pad_out_o => pad_out_out(i),
            pad_t_out_o => pad_t_out_out(i),

            clk_from_ext_i => clk_from_ext(i),
            clk_to_north_o => clk_to_north(i),
            clk_to_south_o => clk_to_south(i)
        );
    end generate;

    -- Clock plumbing mirroring clock distribution in constants
    clk_from_ext <= (
        -- IO bank 1
        0 => clk_to_south(1),
        1 => '1',
        2 => clk_to_north(1),
        3 => clk_to_north(2),
        -- IO bank 2
        4 => clk_to_south(5),
        5 => '1',
        6 => clk_to_north(5),
        7 => clk_to_north(6)
    );

    -- Assign WCK to its appropriate inputs: slice 0 of byte 1 in each IO bank
    pad_in_in(1)(0) <= wck_i(0);
    pad_in_in(5)(0) <= wck_i(1);

    -- Gather statuses needed for resets
    dly_ready_o <= vector_and(dly_ready);
    vtc_ready_o <= vector_and(vtc_ready);
    fifo_empty_o <= vector_or(fifo_empty);


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
        pad_in_in(byte)(slice) <= io_dq_i(i);
        io_dq_t_o(i) <= pad_t_out_out(byte)(slice);
        io_dq_o(i) <= pad_out_out(byte)(slice);
        -- Data flow
        data_in(byte)(slice) <= bank_data_out(i);
        bank_data_in(i) <= data_out(byte)(slice);
        -- Delay control
        delay_dq_out(i) <=
            rx_delay_out(byte)(slice) when delay_rx_tx_n_i else
            tx_delay_out(byte)(slice);
        enable_bitslice_vtc(byte)(slice) <= delay_dq_vtc_in(i);
        rx_load_in(byte)(slice) <= delay_dq_load_in(i) and delay_rx_tx_n_i;
        tx_load_in(byte)(slice) <= delay_dq_load_in(i) and not delay_rx_tx_n_i;
    end generate;

    -- Similarly for DBI
    gen_dbi : for i in 0 to 7 generate
        constant byte : natural := CONFIG_BANK_DBI(i).byte;
        constant slice : natural := CONFIG_BANK_DBI(i).slice;
    begin
        -- IO pad binding
        pad_in_in(byte)(slice) <= io_dbi_n_i(i);
        io_dbi_n_t_o(i) <= pad_t_out_out(byte)(slice);
        io_dbi_n_o(i) <= pad_out_out(byte)(slice);
        -- Data flow
        data_in(byte)(slice) <= bank_dbi_n_out(i);
        bank_dbi_n_in(i) <= data_out(byte)(slice);
        -- Delay control
        delay_dbi_out(i) <=
            rx_delay_out(byte)(slice) when delay_rx_tx_n_i else
            tx_delay_out(byte)(slice);
        enable_bitslice_vtc(byte)(slice) <= delay_dbi_vtc_in(i);
        rx_load_in(byte)(slice) <= delay_dbi_load_in(i) and delay_rx_tx_n_i;
        tx_load_in(byte)(slice) <= delay_dbi_load_in(i) and not delay_rx_tx_n_i;
    end generate;

    -- And finally for EDC (this is input only, so slightly simpler)
    gen_edc : for i in 0 to 7 generate
        constant byte : natural := CONFIG_BANK_EDC(i).byte;
        constant slice : natural := CONFIG_BANK_EDC(i).slice;
    begin
        -- IO pad binding
        pad_in_in(byte)(slice) <= io_edc_i(i);
        -- Data flow
        data_in(byte)(slice) <= X"00";
        bank_edc_in(i) <= data_out(byte)(slice);
        -- Delay control
        delay_edc_out(i) <= rx_delay_out(byte)(slice);
        enable_bitslice_vtc(byte)(slice) <= delay_edc_vtc_in(i);
        rx_load_in(byte)(slice) <= delay_edc_load_in(i) and delay_rx_tx_n_i;
        tx_load_in(byte)(slice) <= '0';
    end generate;

    -- Map delay controls onto inputs and outputs
    delay_dq_vtc_in  <= enable_vtc_i(DELAY_DQ_RANGE);
    delay_dbi_vtc_in <= enable_vtc_i(DELAY_DBI_RANGE);
    delay_edc_vtc_in <= enable_vtc_i(DELAY_EDC_RANGE);
    delay_tri_vtc_in <= enable_vtc_i(DELAY_TRI_RANGE);
    delay_dq_load_in  <= load_delay_i(DELAY_DQ_RANGE);
    delay_dbi_load_in <= load_delay_i(DELAY_DBI_RANGE);
    delay_edc_load_in <= load_delay_i(DELAY_EDC_RANGE);
    delay_tri_load_in <= load_delay_i(DELAY_TRI_RANGE);
    delay_o <= (
        DELAY_DQ_RANGE => delay_dq_out,
        DELAY_DBI_RANGE => delay_dbi_out,
        DELAY_EDC_RANGE => delay_edc_out,
        DELAY_TRI_RANGE => delay_tri_out
    );


    -- Finally flatten the data across 8 ticks
    map_data : entity work.gddr6_phy_map_data port map (
        clk_i => reg_clk_i,

        enable_dbi_i => enable_dbi_i,

        bank_data_i => bank_data_in,
        bank_data_o => bank_data_out,
        bank_dbi_n_i => bank_dbi_n_in,
        bank_dbi_n_o => bank_dbi_n_out,
        bank_edc_i => bank_edc_in,

        data_i => data_i,
        data_o => data_o,
        edc_o => edc_o
    );
end;
