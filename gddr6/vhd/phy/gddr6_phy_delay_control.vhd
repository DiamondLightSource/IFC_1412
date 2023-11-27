-- Mapping from simple delay control interface to CA and DQ delay controls

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_phy_defs.all;

entity gddr6_phy_delay_control is
    port (
        clk_i : std_ulogic;

        -- Control interface from registers
        delay_address_i : in unsigned(7 downto 0);
        delay_i : in unsigned(8 downto 0);
        delay_up_down_n_i : in std_ulogic;
        byteslip_i : in std_ulogic;
        read_write_n_i : in std_ulogic;
        delay_o : out unsigned(8 downto 0);
        strobe_i : in std_ulogic;
        ack_o : out std_ulogic;

        -- Bitslip control
        bitslip_address_o : out unsigned(6 downto 0);
        bitslip_delay_o : out unsigned(2 downto 0);
        bitslip_strobe_o : out std_ulogic;

        -- Delay controls and readbacks
        delay_control_o : out delay_control_t;
        delay_readbacks_i : in delay_readbacks_t;

        -- CA control
        ca_tx_delay_ce_o : out std_ulogic_vector(15 downto 0);
        delay_ca_tx_i : in vector_array(15 downto 0)(8 downto 0);

        enable_bitslice_vtc_o : out std_ulogic
    );
end;

architecture arch of gddr6_phy_delay_control is
    signal strobe_in : std_ulogic;              -- Start working on request

    signal is_bitslip : boolean;

    signal running_delay : std_ulogic := '0';
    signal delay_count : delay_i'SUBTYPE;

    signal delay_address : delay_address_i'SUBTYPE := (others => '0');

    signal ce_out : std_ulogic_vector(255 downto 0) := (others => '0');
    signal bs_out : std_ulogic_vector(255 downto 0) := (others => '0');

    signal delays_in : vector_array(255 downto 0)(8 downto 0);

    -- Delay controls.  Assigned separately before being gathered into a single
    -- output structure to avoid VHDL process conflicts
    signal delay_up_down_n : std_ulogic := '0';
    signal dq_rx_delay_vtc : std_ulogic_vector(63 downto 0);
    signal dq_rx_delay_ce : std_ulogic_vector(63 downto 0);
    signal dq_tx_delay_vtc : std_ulogic_vector(63 downto 0);
    signal dq_tx_delay_ce : std_ulogic_vector(63 downto 0);
    signal dq_rx_byteslip : std_ulogic_vector(63 downto 0);
    signal dbi_rx_delay_vtc : std_ulogic_vector(7 downto 0);
    signal dbi_rx_delay_ce : std_ulogic_vector(7 downto 0);
    signal dbi_tx_delay_vtc : std_ulogic_vector(7 downto 0);
    signal dbi_tx_delay_ce : std_ulogic_vector(7 downto 0);
    signal dbi_rx_byteslip : std_ulogic_vector(7 downto 0);
    signal edc_rx_delay_vtc : std_ulogic_vector(7 downto 0);
    signal edc_rx_delay_ce : std_ulogic_vector(7 downto 0);
    signal edc_rx_byteslip : std_ulogic_vector(7 downto 0);

    -- Shorthand alias just to help table layout below
    alias rb_i : delay_readbacks_t is delay_readbacks_i;

begin
    -- Map output strobes according to addressing.  The bitslice looks after
    -- itself and just takes an address
    -- The address map is as follows:
    --   00aaaaaa    Control IDELAY for DQ bit selected by aaaaaaa
    --   01aaaaaa    Control ODELAY for DQ bit selected by aaaaaaa
    --   10aaaaaa    Set bitslip input for selected DQ bit
    --   11000aaa    Set bitslip input for DBI bit aaa
    --   11001aaa    Set bitslip input for EDC bit aaa
    --   11010aaa    Control IDELAY for DBI bit aaa
    --   11011aaa    Control ODELAY for DBI bit aaa
    --   11100aaa    Control IDELAY for EDC bit aaa
    --   11101xxx    (unassigned)
    --   1111cccc    Control ODELAY for CA bit selected by cccc:
    --               0..9        CA[cccc] (cccc = 3 is ignored)
    --               10          CABI_N
    --               11..14      CA3[cccc-11]
    --               15          CKE_N
    dq_rx_delay_ce    <= ce_out(2#0011_1111# downto 2#0000_0000#); -- 00xx_xxxx
    dq_tx_delay_ce    <= ce_out(2#0111_1111# downto 2#0100_0000#); -- 01xx_xxxx
    dbi_rx_delay_ce   <= ce_out(2#1101_0111# downto 2#1101_0000#); -- 1101_0xxx
    dbi_tx_delay_ce   <= ce_out(2#1101_1111# downto 2#1101_1000#); -- 1101_1xxx
    edc_rx_delay_ce   <= ce_out(2#1110_0111# downto 2#1110_0000#); -- 1110_0xxx
    ca_tx_delay_ce_o  <= ce_out(2#1111_1111# downto 2#1111_0000#); -- 1111_xxxx

    -- Byteslips use similar addresses on the low part
    dq_rx_byteslip    <= bs_out(2#0011_1111# downto 2#0000_0000#); --  0xx_xxxx
    dbi_rx_byteslip   <= bs_out(2#0100_0111# downto 2#0100_0000#); --  100_0xxx
    edc_rx_byteslip   <= bs_out(2#0100_1111# downto 2#0100_1000#); --  100_1xxx

    -- Use the same mapping for delay readbacks (no bitslip readback)
    delays_in <= (
        2#0011_1111# downto 2#0000_0000# => rb_i.dq_rx_delay,      -- 00xx_xxxx
        2#0111_1111# downto 2#0100_0000# => rb_i.dq_tx_delay,      -- 01xx_xxxx
        2#1100_1111# downto 2#1000_0000# => (others => '-'),
        2#1101_0111# downto 2#1101_0000# => rb_i.dbi_rx_delay,     -- 1101_0xxx
        2#1101_1111# downto 2#1101_1000# => rb_i.dbi_tx_delay,     -- 1101_1xxx
        2#1110_0111# downto 2#1110_0000# => rb_i.edc_rx_delay,     -- 1110_0xxx
        2#1110_1111# downto 2#1110_1000# => (others => '-'),
        2#1111_1111# downto 2#1111_0000# => delay_ca_tx_i          -- 1111_xxxx
    );

    -- The address range 10xx_xxxx and 1100_xxxx is under bitslice control.
    -- Note that this is only valid when strobe_in is active!
    is_bitslip <= strobe_in = '1' and read_write_n_i = '0' and
        (delay_address_i(7 downto 6) = "10" or
         delay_address_i(7 downto 4) = "1100");


    -- This helper allows us to overlap processing and acknowledge
    write_strobe_ack : entity work.strobe_ack port map (
        clk_i => clk_i,
        strobe_i => strobe_i,
        ack_o => ack_o,
        busy_i => running_delay,
        strobe_o => strobe_in
    );

    process (clk_i) begin
        if rising_edge(clk_i) then
            bitslip_strobe_o <= to_std_ulogic(is_bitslip) and strobe_in;

            if strobe_in then
                -- Register parameters on incoming strobe while they're valid
                delay_address <= delay_address_i;

                if byteslip_i or read_write_n_i then
                    -- No action required here
                elsif is_bitslip then
                    -- Forward relevant part of address to bitslip control
                    bitslip_address_o <=
                        delay_address_i(bitslip_address_o'RANGE);
                    bitslip_delay_o <= delay_i(bitslip_delay_o'RANGE);
                else
                    delay_up_down_n <= delay_up_down_n_i;
                    delay_count <= delay_i;
                    running_delay <= '1';
                end if;
            elsif running_delay then
                if delay_count > 0 then
                    delay_count <= delay_count - 1;
                else
                    running_delay <= '0';
                end if;
            end if;

            compute_strobe(ce_out, to_integer(delay_address), running_delay);
            if strobe_in then
                compute_strobe(bs_out, to_integer(delay_address_i),
                    byteslip_i and not read_write_n_i);
            else
                bs_out <= (others => '0');
            end if;

            -- Decode incoming delays from given address
            if strobe_in then
                delay_o <= unsigned(delays_in(to_integer(delay_address_i)));
            end if;
        end if;
    end process;

    -- When operating in DELAY = "COUNT" mode we must hold VTC low
    enable_bitslice_vtc_o <= '0';

    dq_rx_delay_vtc <= (others => '1');
    dq_tx_delay_vtc <= (others => '1');
    dbi_rx_delay_vtc <= (others => '1');
    dbi_tx_delay_vtc <= (others => '1');
    edc_rx_delay_vtc <= (others => '1');

    delay_control_o <= (
        delay_up_down_n => delay_up_down_n,
        dq_rx_delay_vtc => dq_rx_delay_vtc,
        dq_rx_delay_ce => dq_rx_delay_ce,
        dq_tx_delay_vtc => dq_tx_delay_vtc,
        dq_tx_delay_ce => dq_tx_delay_ce,
        dq_rx_byteslip => dq_rx_byteslip,
        dbi_rx_delay_vtc => dbi_rx_delay_vtc,
        dbi_rx_delay_ce => dbi_rx_delay_ce,
        dbi_tx_delay_vtc => dbi_tx_delay_vtc,
        dbi_tx_delay_ce => dbi_tx_delay_ce,
        dbi_rx_byteslip => dbi_rx_byteslip,
        edc_rx_delay_vtc => edc_rx_delay_vtc,
        edc_rx_delay_ce => edc_rx_delay_ce,
        edc_rx_byteslip => edc_rx_byteslip
    );
end;
