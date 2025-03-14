-- Mapping from simple delay control interface to CA and DQ delay controls

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_phy_defs.all;

entity gddr6_phy_delay_control is
    port (
        clk_i : in std_ulogic;

        -- Control interface from registers
        setup_i : in setup_delay_t;
        setup_o : out setup_delay_result_t;

        -- Delay controls and readbacks
        bitslice_control_o : out bitslice_delay_control_t
            := IDLE_BITSLICE_DELAY_CONTROL;
        bitslice_delays_i : in bitslice_delay_readbacks_t;
        bitslip_control_o : out bitslip_delay_control_t
            := IDLE_BITSLIP_DELAY_CONTROL;
        bitslip_delays_i : in bitslip_delay_readbacks_t;

        phase_direction_o : out std_ulogic;
        phase_step_o : out std_ulogic;
        phase_step_ack_i : in std_ulogic;
        phase_i : in unsigned(7 downto 0)
    );
end;

architecture arch of gddr6_phy_delay_control is
    -- Target and address decoding
    constant TARGET_IDELAY : natural := 0;
    constant TARGET_ODELAY : natural := 1;
    constant TARGET_IBITSLIP : natural := 2;
    constant TARGET_OBITSLIP : natural := 3;

    -- Strobe arrays for output indexed by target type, used for both bitslip
    -- and I/O DELAY control
    signal ce_out : vector_array(0 to 3)(79 downto 0)
        := (others => (others => '0'));

    -- Incoming delays
    signal delays_in : vector_array_array(3 downto 0)(127 downto 0)(8 downto 0);

    -- Read and write control
    signal write_strobe_in : std_ulogic;
    signal write_ack : std_ulogic;
    signal read_ack : std_ulogic;
    signal delay_out : unsigned(8 downto 0);

    -- Captured incoming request
    signal address : natural range 0 to 79; -- I suppose 127 would be honest!
    signal target : natural range 0 to 3;
    signal up_down_n : std_ulogic := '0';
    signal bitslip_delay : unsigned(2 downto 0);

    -- Strobe controls
    signal enable_strobe : std_ulogic := '0';

    -- State machine for writing delays:
    --
    --        /-------------------------------------\
    --        v                                     |
    --      IDLE -----> DELAY -----> RUNOUT -----> END
    --        |         |  ^           ^            ^
    --        |         v  |           |            |
    --        |         DWELL          |            |
    --        \------------------------/------------/
    --
    -- The DWELL state is needed to separate CE strobes (this is incredibly
    -- poorly documented in UG571).
    type write_state_t is (
        WRITE_IDLE, WRITE_DELAY, WRITE_DWELL, WRITE_RUNOUT, WRITE_END);
    signal write_state : write_state_t := WRITE_IDLE;

    -- State machine counters
    signal delay_counter : unsigned(8 downto 0);
    constant DWELL_COUNT : unsigned(2 downto 0) := to_unsigned(4, 3);
    signal dwell_counter : unsigned(2 downto 0);
    constant RUNOUT_COUNT : unsigned(1 downto 0) := to_unsigned(3, 2);
    signal runout_counter : unsigned(1 downto 0);


    -- Used to convert 3 bit bitslip values to common delay readback format
    function resize(delays : unsigned_array) return vector_array
    is
        variable result : vector_array(delays'RANGE)(8 downto 0);
    begin
        for n in delays'RANGE loop
            result(n) := std_ulogic_vector(resize(delays(n), 9));
        end loop;
        return result;
    end;

begin
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


    process (clk_i)
        procedure count_delay(
            signal counter : inout unsigned; next_state : write_state_t) is
        begin
            if counter > 0 then
                counter <= counter - 1;
            else
                write_state <= next_state;
            end if;
        end;

        -- Uses selected address and target to generate selected strobe
        procedure compute_strobe(value : std_ulogic) is
        begin
            for t in ce_out'RANGE loop
                for a in ce_out'ELEMENT'RANGE loop
                    if t = target and a = address then
                        ce_out(t)(a) <= value;
                    else
                        ce_out(t)(a) <= '0';
                    end if;
                end loop;
            end loop;
        end;

    begin
        if rising_edge(clk_i) then
            case write_state is
                when WRITE_IDLE =>
                    runout_counter <= RUNOUT_COUNT;

                    if write_strobe_in then
                        -- Capture all incoming state
                        address <= to_integer(setup_i.address);
                        target <= to_integer(setup_i.target);
                        up_down_n <= setup_i.up_down_n;
                        delay_counter <= setup_i.delay;
                        bitslip_delay <= setup_i.delay(2 downto 0);

                        -- Transition into the appropriate state depending on
                        -- selected target and on whether writing is enabled
                        case to_integer(setup_i.target) is
                            when TARGET_IDELAY | TARGET_ODELAY =>
                                if setup_i.enable_write then
                                    enable_strobe <= '1';
                                    write_state <= WRITE_DELAY;
                                else
                                    write_state <= WRITE_END;
                                end if;

                            when TARGET_IBITSLIP | TARGET_OBITSLIP =>
                                if setup_i.enable_write then
                                    enable_strobe <= '1';
                                    write_state <= WRITE_RUNOUT;
                                else
                                    write_state <= WRITE_END;
                                end if;

                            when others =>
                                -- No action required
                        end case;
                    end if;

                when WRITE_DELAY =>
                    -- Hold in WRITE_DELAY state for requested duration, insert
                    -- WRITE_DWELL states between ticks
                    dwell_counter <= DWELL_COUNT;
                    enable_strobe <= '0';
                    if delay_counter > 0 then
                        write_state <= WRITE_DWELL;
                    end if;
                    count_delay(delay_counter, WRITE_RUNOUT);

                when WRITE_DWELL =>
                    -- Insert 5 tick delay between CE strobes
                    enable_strobe <= to_std_ulogic(dwell_counter = 0);
                    count_delay(dwell_counter, WRITE_DELAY);

                when WRITE_RUNOUT =>
                    -- Extra delay needed so that readbacks are valid
                    enable_strobe <= '0';
                    count_delay(runout_counter, WRITE_END);

                when WRITE_END =>
                    -- On completion update the readback.  For a read-only
                    -- action this is all we do!
                    delay_out <= unsigned(delays_in(target)(address));
                    write_state <= WRITE_IDLE;
            end case;

            -- Generate the control strobes.
            compute_strobe(enable_strobe);

            -- Map and register the readbacks
            delays_in <= (
                TARGET_IDELAY => (
                    DELAY_DQ_RANGE  => bitslice_delays_i.dq_rx_delay,
                    DELAY_DBI_RANGE => bitslice_delays_i.dbi_rx_delay,
                    DELAY_EDC_RANGE => bitslice_delays_i.edc_rx_delay,
                    others => (others => '0')),
                TARGET_ODELAY => (
                    DELAY_DQ_RANGE  => bitslice_delays_i.dq_tx_delay,
                    DELAY_DBI_RANGE => bitslice_delays_i.dbi_tx_delay,
                    others => (others => '0')),
                TARGET_IBITSLIP => (
                    DELAY_DQ_RANGE  => resize(bitslip_delays_i.dq_rx_delay),
                    DELAY_DBI_RANGE => resize(bitslip_delays_i.dbi_rx_delay),
                    DELAY_EDC_RANGE => resize(bitslip_delays_i.edc_rx_delay),
                    others => (others => '0')),
                TARGET_OBITSLIP => (
                    DELAY_DQ_RANGE  => resize(bitslip_delays_i.dq_tx_delay),
                    DELAY_DBI_RANGE => resize(bitslip_delays_i.dbi_tx_delay),
                    others => (others => '0')),
                others => (others => (others => '0'))
            );


            -- Map output strobes according to addressing
            bitslice_control_o <= (
                up_down_n => up_down_n,

                -- CE for IDELAY and ODELAY following the address map above
                dq_rx_ce =>  ce_out(TARGET_IDELAY)(DELAY_DQ_RANGE),
                dq_tx_ce =>  ce_out(TARGET_ODELAY)(DELAY_DQ_RANGE),
                dbi_rx_ce => ce_out(TARGET_IDELAY)(DELAY_DBI_RANGE),
                dbi_tx_ce => ce_out(TARGET_ODELAY)(DELAY_DBI_RANGE),
                edc_rx_ce => ce_out(TARGET_IDELAY)(DELAY_EDC_RANGE)
            );

            bitslip_control_o <= (
                dq_rx_strobe =>  ce_out(TARGET_IBITSLIP)(DELAY_DQ_RANGE),
                dq_tx_strobe =>  ce_out(TARGET_OBITSLIP)(DELAY_DQ_RANGE),
                dbi_rx_strobe => ce_out(TARGET_IBITSLIP)(DELAY_DBI_RANGE),
                dbi_tx_strobe => ce_out(TARGET_OBITSLIP)(DELAY_DBI_RANGE),
                edc_rx_strobe => ce_out(TARGET_IBITSLIP)(DELAY_EDC_RANGE),
                delay => bitslip_delay
            );
        end if;
    end process;

    setup_o <= (
        write_ack => write_ack,
        read_ack => read_ack,
        delay => delay_out,
        phase_ack => phase_step_ack_i,
        phase => phase_i
    );
    phase_direction_o <= setup_i.up_down_n;
    phase_step_o <= setup_i.phase_strobe;
end;
