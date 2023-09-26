-- Mapping from simple delay control interface to CA and DQ delay controls

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity gddr6_phy_delay_control is
    port (
        ck_clk_i : std_ulogic;

        -- Control interface from registers on CK clock
        delay_address_i : in unsigned(7 downto 0);
        delay_i : in unsigned(7 downto 0);
        delay_up_down_n_i : in std_ulogic;
        strobe_i : in std_ulogic;
        ack_o : out std_ulogic;

        -- Bitslip control on CK clock
        bitslip_address_o : out unsigned(6 downto 0);
        bitslip_delay_o : out unsigned(3 downto 0);
        bitslip_strobe_o : out std_ulogic;


        -- All I/O delay controls are on delay clock synchronous with ck_clk_i
        -- but at half frequency
        delay_clk_i : std_ulogic;

        -- Delay direction common to all I/O DELAY controls on delay clock
        delay_up_down_n_o : out std_ulogic := '0';

        -- CA control
        ca_tx_delay_ce_o : out std_ulogic_vector(15 downto 0);
        -- DQ controls
        dq_rx_delay_ce_o : out std_ulogic_vector(63 downto 0);
        dq_tx_delay_ce_o : out std_ulogic_vector(63 downto 0);
        dbi_rx_delay_ce_o : out std_ulogic_vector(7 downto 0);
        dbi_tx_delay_ce_o : out std_ulogic_vector(7 downto 0);
        edc_rx_delay_ce_o : out std_ulogic_vector(7 downto 0);

        enable_bitslice_vtc_o : out std_ulogic
    );
end;

architecture arch of gddr6_phy_delay_control is
    -- Delay write handshaking
    signal pending_request : std_ulogic := '0'; -- Strobe seen, but waiting
    signal strobe_in : std_ulogic;              -- Start working on request

    -- Handshake from CK => Delay and back again.  State machine is a
    -- combination of write_request, set in response to strobe_in, and
    -- runner_active, set in response to write_request and reset when done.
    -- States:
    --  not request, not active:    Idle, waiting for strobe_in
    --  request, not active:        Waking delay counter in Delay domain
    --  request, active:            Delay counter started
    --  not request, active:        Waiting for counter to complete
    signal write_request : std_ulogic := '0';   -- Waiting for write to complete
    signal runner_active : std_ulogic := '0';   -- Copy of running delay
    signal write_busy : std_ulogic;

    signal is_bitslip : boolean;

    signal running_delay : std_ulogic := '0';
    signal delay_count : delay_i'SUBTYPE;

    signal delay_address_in : delay_address_i'SUBTYPE;
    signal delay_address : delay_address_i'SUBTYPE := (others => '0');
    signal delay_up_down_n_in : std_ulogic;
    signal delay_in : delay_i'SUBTYPE;

    signal ce_out : std_ulogic_vector(255 downto 0) := (others => '0');

begin
    -- Map output strobes according to addressing.  The bitslice looks after
    -- itself and just takes an address
    dq_rx_delay_ce_o  <= ce_out(2#0011_1111# downto 2#0000_0000#); -- 00xx_xxxx
    dq_tx_delay_ce_o  <= ce_out(2#0111_1111# downto 2#0100_0000#); -- 01xx_xxxx
    dbi_rx_delay_ce_o <= ce_out(2#1101_0111# downto 2#1101_0000#); -- 1101_0xxx
    dbi_tx_delay_ce_o <= ce_out(2#1101_1111# downto 2#1101_1000#); -- 1101_1xxx
    edc_rx_delay_ce_o <= ce_out(2#1110_0111# downto 2#1110_0000#); -- 1110_0xxx
    ca_tx_delay_ce_o  <= ce_out(2#1111_1111# downto 2#1111_0000#); -- 1111_xxxx


    -- Start processing the next request when we're not busy
    strobe_in <= not write_busy and (strobe_i or pending_request);
    write_busy <= write_request or runner_active;

    -- The address range 10xx_xxxx and 1100_xxxx is under bitslice control.
    -- Note that this is only valid when strobe_in is active!
    is_bitslip <= strobe_in = '1' and
        (delay_address_i(7 downto 6) = "10" or
         delay_address_i(7 downto 4) = "1100");


    process (ck_clk_i) begin
        if rising_edge(ck_clk_i) then
            -- Hang onto any request we can't complete just yet
            pending_request <= write_busy and (strobe_i or pending_request);
            -- We can acknowledge the request as soon as we start working on it
            ack_o <= strobe_in;

            bitslip_strobe_o <= to_std_ulogic(is_bitslip) and strobe_in;

            if strobe_in then
                -- Register parameters on incoming strobe while they're valid
                delay_address_in <= delay_address_i;
                delay_up_down_n_in <= delay_up_down_n_i;
                delay_in <= delay_i;

                if is_bitslip then
                    -- Forward relevant part of address to bitslip control
                    bitslip_address_o <= delay_address_i(6 downto 0);
                    bitslip_delay_o <= delay_i(3 downto 0);
                else
                    write_request <= '1';
                end if;
            elsif runner_active then
                write_request <= '0';
            end if;

            -- Take a copy of the running state of the runner.  This is good
            -- practice to avoid logic across clock domains, but is fairly
            runner_active <= running_delay;
        end if;
    end process;


    -- Generate CE output on delay clock domain, report completion when done
    process (delay_clk_i) begin
        if rising_edge(delay_clk_i) then
            if running_delay then
                if delay_count > 0 then
                    delay_count <= delay_count - 1;
                else
                    running_delay <= '0';
                end if;
            elsif write_request then
                delay_up_down_n_o <= delay_up_down_n_in;
                delay_address <= delay_address_in;
                delay_count <= delay_in;
                running_delay <= '1';
            end if;

            compute_strobe(ce_out, to_integer(delay_address), running_delay);
        end if;
    end process;


    -- When operating in DELAY = "COUNT" mode we must hold VTC low
    enable_bitslice_vtc_o <= '0';
end;
