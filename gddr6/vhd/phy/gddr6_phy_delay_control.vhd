-- Mapping from simple delay control interface to CA and DQ delay controls

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_phy_defs.all;

entity gddr6_phy_delay_control is
    port (
        clk_i : std_ulogic;

        -- Control interface from registers
        setup_i : in setup_delay_t;
        setup_o : out setup_delay_result_t;

        -- Bitslip control
        bitslip_address_o : out unsigned(6 downto 0) := (others => '0');
        bitslip_delay_o : out unsigned(2 downto 0) := (others => '0');
        bitslip_strobe_o : out std_ulogic := '0';

        -- Delay controls and readbacks
        delay_control_o : out delay_control_t;
        delay_readbacks_i : in delay_readbacks_t;

        -- CA control
        ca_tx_delay_ce_o : out std_ulogic_vector(15 downto 0);
        delay_ca_tx_i : in vector_array(15 downto 0)(8 downto 0)
    );
end;

architecture arch of gddr6_phy_delay_control is
    -- Strobe arrays for output
    signal ce_out : std_ulogic_vector(255 downto 0) := (others => '0');
    signal vtc_out : std_ulogic_vector(255 downto 0) := (others => '1');
    signal bs_out : std_ulogic_vector(255 downto 0) := (others => '0');

    signal delays_in : vector_array(255 downto 0)(8 downto 0);

    signal write_strobe_in : std_ulogic;
    signal write_ack : std_ulogic;
    signal read_ack : std_ulogic;
    signal delay_out : unsigned(8 downto 0);

    signal delay_count : unsigned(8 downto 0);
    signal address : unsigned(7 downto 0) := (others => '0');
    signal delay_up_down_n : std_ulogic := '0';

    type write_state_t is (
        WRITE_IDLE, WRITE_WAIT_START, WRITE_DELAY, WRITE_WAIT_END);
    signal write_state : write_state_t := WRITE_IDLE;
    constant WAIT_VTC_COUNT : natural := 10;
    signal wait_counter : natural range 0 to WAIT_VTC_COUNT;

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
    delay_control_o <= (
        up_down_n => delay_up_down_n,
        -- CE for IDELAY and ODELAY following the address map above
        dq_rx_ce =>   ce_out (2#0011_1111# downto 2#0000_0000#),    -- 00xx_xxxx
        dq_tx_ce =>   ce_out (2#0111_1111# downto 2#0100_0000#),    -- 01xx_xxxx
        dbi_rx_ce =>  ce_out (2#1101_0111# downto 2#1101_0000#),    -- 1101_0xxx
        dbi_tx_ce =>  ce_out (2#1101_1111# downto 2#1101_1000#),    -- 1101_1xxx
        edc_rx_ce =>  ce_out (2#1110_0111# downto 2#1110_0000#),    -- 1110_0xxx
        -- VTC uses the same address mapping as CE
        dq_rx_vtc =>  vtc_out(2#0011_1111# downto 2#0000_0000#),    -- 00xx_xxxx
        dq_tx_vtc =>  vtc_out(2#0111_1111# downto 2#0100_0000#),    -- 01xx_xxxx
        dbi_rx_vtc => vtc_out(2#1101_0111# downto 2#1101_0000#),    -- 1101_0xxx
        dbi_tx_vtc => vtc_out(2#1101_1111# downto 2#1101_1000#),    -- 1101_1xxx
        edc_rx_vtc => vtc_out(2#1110_0111# downto 2#1110_0000#),    -- 1110_0xxx
        -- Byteslips use similar addresses on the low part
        dq_rx_byteslip =>  bs_out(2#0011_1111# downto 2#0000_0000#), -- 0xx_xxxx
        dbi_rx_byteslip => bs_out(2#0100_0111# downto 2#0100_0000#), -- 100_0xxx
        edc_rx_byteslip => bs_out(2#0100_1111# downto 2#0100_1000#)  -- 100_1xxx
    );
    ca_tx_delay_ce_o <= ce_out(2#1111_1111# downto 2#1111_0000#);   -- 1111_xxxx

    -- Use the same mapping for readbacks (no bitslip or byteslip readback)
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


    -- This helper allows us to overlap processing and acknowledge
    write_strobe_ack : entity work.strobe_ack port map (
        clk_i => clk_i,
        strobe_i => setup_i.write_strobe,
        ack_o => write_ack,
        busy_i => to_std_ulogic(write_state /= WRITE_IDLE),
        strobe_o => write_strobe_in
    );

    -- Reading must block until any writing action completes
    read_strobe_ack : entity work.strobe_ack port map (
        clk_i => clk_i,
        strobe_i => setup_i.read_strobe,
        ack_o => read_ack,
        busy_i => to_std_ulogic(write_state /= WRITE_IDLE),
        strobe_o => open
    );


    control : process (clk_i)
        variable do_write : std_ulogic;
        variable is_bitslip : std_ulogic;
        variable is_byteslip : std_ulogic;
        variable do_vtc : std_ulogic;
        variable do_capture : boolean;
        variable bitslip_address : natural;

    begin
        if rising_edge(clk_i) then
            -- Decode writes requiring special treatment: bitslip and byteslip
            -- can complete immediately without triggering the state machine
            do_write := write_strobe_in and setup_i.enable_write;
            -- Byteslip is a special operation and overrides anything else
            is_byteslip := do_write and setup_i.byteslip;
            -- The address range 10xx_xxxx and 1100_xxxx is under bitslice
            -- control and doesn't use VTC handshaking.  Conditional assignment
            -- avoids evaluating comparison when invalid.
            is_bitslip := to_std_ulogic(
                    setup_i.address(7 downto 6) = "10" or
                    setup_i.address(7 downto 4) = "1100")
                when do_write and not is_byteslip else '0';
            -- Trigger VTC unless we're doing a bitslip or byteslip write
            do_vtc := write_strobe_in and not is_bitslip and not is_byteslip;

            if write_strobe_in then
                -- Capture control parameters so we can acknowledge the request
                -- and carry on processing
                delay_count <= setup_i.delay;
                address <= setup_i.address;
                delay_up_down_n <= setup_i.up_down_n;
            end if;

            -- The write state machine goes through the following steps:
            --  * Wait 10 ticks with VTC low
            --  * Perform action, either reset for one tick, or delay for
            --    delay_count ticks
            --  * Wait a further 10 ticks before going idle
            case write_state is
                when WRITE_IDLE =>
                    -- Wait for start of VTC sequence
                    if do_vtc then
                        wait_counter <= WAIT_VTC_COUNT;
                        if do_write then
                            -- For writing need to go through full process
                            write_state <= WRITE_WAIT_START;
                        else
                            -- For reading can bypass initial read and action
                            write_state <= WRITE_WAIT_END;
                        end if;
                    end if;
                when WRITE_WAIT_START =>
                    -- Wait for initial delay before doing write
                    if wait_counter > 0 then
                        wait_counter <= wait_counter - 1;
                    else
                        wait_counter <= WAIT_VTC_COUNT;
                        write_state <= WRITE_DELAY;
                    end if;
                when WRITE_DELAY =>
                    -- Hold in WRITE_DELAY state for request duration
                    if delay_count > 0 then
                        delay_count <= delay_count - 1;
                    else
                        write_state <= WRITE_WAIT_END;
                    end if;
                when WRITE_WAIT_END =>
                    -- Finally wait again before asserting VTC
                    if wait_counter > 0 then
                        wait_counter <= wait_counter - 1;
                    else
                        write_state <= WRITE_IDLE;
                    end if;
            end case;
            do_capture := write_state = WRITE_WAIT_END and wait_counter = 0;


            -- Enable CE while in WRITE_DELAY state
            compute_strobe(
                ce_out, to_integer(address),
                to_std_ulogic(write_state = WRITE_DELAY), '0');
            -- Disable VTC while not WRITE_IDLE, otherwise leave enabled
            compute_strobe(
                vtc_out, to_integer(address),
                to_std_ulogic(write_state = WRITE_IDLE), '1');

            -- These two strobes happen at the point of the write request, so
            -- the current address needs to be used.
            -- The address is assigned separately here to avoid simulation
            -- complaints when setup_i.address is invalid (only valid when
            -- writing bitslip).
            bitslip_address :=
                to_integer(setup_i.address) when is_byteslip else 0;
            compute_strobe(bs_out, bitslip_address, is_byteslip, '0');

            -- Bitslip strobe is directly from bitslip request (for the moment)
            if is_bitslip then
                bitslip_address_o <= setup_i.address(6 downto 0);
                bitslip_delay_o <= setup_i.delay(2 downto 0);
            end if;
            bitslip_strobe_o <= is_bitslip;

            -- Decode incoming delays from given address
            if do_capture then
                delay_out <= unsigned(delays_in(to_integer(address)));
            end if;
        end if;
    end process;

    setup_o <= (
        write_ack => write_ack,
        read_ack => read_ack,
        delay => delay_out
    );
end;
