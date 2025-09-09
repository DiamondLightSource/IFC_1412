-- Control and timing for SPI interface to multiplexed LMK devices

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.lmk04616_register_defines.all;

entity lmk04616_control is
    port (
        clk_i : in std_ulogic;

        -- Register interface
        write_strobe_i : in std_ulogic;
        write_data_i : in reg_data_t;
        write_ack_o : out std_ulogic := '0';
        read_strobe_i : in std_ulogic;
        read_data_o : out reg_data_t;
        read_ack_o : out std_ulogic := '0';

        -- Miscellaneous controls to LMK
        lmk_ctl_sel_o : out std_ulogic := '0';
        lmk_reset_l_o : out std_ulogic := '1';
        lmk_sync_o : out std_ulogic := '0';
        lmk_status_i : in std_ulogic_vector(0 to 1);

        -- Interface to status monitoring
        status_sel_i : in std_ulogic;
        status_idle_o : out std_ulogic;

        -- Interface to SPI
        spi_read_write_n_o : out std_ulogic := '0';
        spi_address_o : out std_ulogic_vector(14 downto 0);
        spi_start_o : out std_ulogic := '0';
        spi_busy_i : in std_ulogic;
        spi_data_i : in std_ulogic_vector(7 downto 0);
        spi_data_o : out std_ulogic_vector(7 downto 0)
    );
end;

architecture arch of lmk04616_control is
    -- According to the documentation for the LMK access multiplexing device,
    -- a TI TXBN0304, it can take up to 170ns for the selection to fully
    -- transition from one LMK to the other.  At 250MHz this corresponds to 43
    -- ticks!
    constant T_SWITCH : natural := 43;

    type write_state_t is (
        STATE_IDLE, STATE_SWITCH, STATE_WAIT_BUSY, STATE_BUSY);
    signal write_state : write_state_t := STATE_IDLE;

    -- Counter used to delay processing when transition required
    signal switch_delay : unsigned(bits(T_SWITCH)-1 downto 0);
    signal write_enable : std_ulogic;
    signal enable_status : std_ulogic := '0';

    signal write_busy : std_ulogic := '0';
    signal read_busy : std_ulogic := '0';
    -- Set if a pending write strobe was seen when starting a state switch
    signal start_write : std_ulogic := '0';

begin
    process (clk_i)
        -- Invoke this in response to a write request once any LMK
        -- selection write transition is complete.  The write is only
        -- acknowledged when completed.
        procedure do_write(variable write_ack : inout std_ulogic) is
        begin
            lmk_reset_l_o <= not write_data_i(LMK04616_RESET_BIT);
            lmk_sync_o <= write_data_i(LMK04616_SYNC_BIT);

            if write_data_i(LMK04616_ENABLE_BIT) then
                -- If SPI write enabled then start SPI transaction
                spi_data_o <= write_data_i(LMK04616_DATA_BITS);
                spi_address_o <= write_data_i(LMK04616_ADDRESS_BITS);
                spi_read_write_n_o <= write_data_i(LMK04616_R_WN_BIT);
                spi_start_o <= '1';
                write_state <= STATE_WAIT_BUSY;
            else
                -- Otherwise can acknowledge the write straightaway
                write_ack := '1';
                write_state <= STATE_IDLE;
            end if;
        end;

        -- Reading returns all relevant state
        procedure do_read(variable read_ack : inout std_ulogic) is
        begin
            -- Assemble outgoing data
            read_data_o <= (
                LMK04616_DATA_BITS => spi_data_i,
                LMK04616_ADDRESS_BITS => spi_address_o,
                LMK04616_SELECT_BIT => lmk_ctl_sel_o,
                LMK04616_RESET_BIT => not lmk_reset_l_o,
                LMK04616_SYNC_BIT => lmk_sync_o,
                LMK04616_STATUS_BITS => reverse(lmk_status_i),
                LMK04616_ENABLE_STATUS_BIT => enable_status,
                others => '0'
            );
            read_ack := '1';
        end;

        variable write_strobe_in : std_ulogic;
        variable read_strobe_in : std_ulogic;
        variable next_sel : std_ulogic;
        variable write_ack : std_ulogic;
        variable read_ack : std_ulogic;

    begin
        if rising_edge(clk_i) then
            write_strobe_in := write_strobe_i or write_busy;
            read_strobe_in := read_strobe_i or read_busy;
            -- Keep track of whether we're acknowledging the write on this cycle
            write_ack := '0';
            read_ack := '0';

            case write_state is
                when STATE_IDLE =>
                    if write_strobe_in then
                        -- Control over status monitoring is unconditional
                        enable_status <=
                            write_data_i(LMK04616_ENABLE_STATUS_BIT);
                        next_sel := write_data_i(LMK04616_SELECT_BIT);
                    elsif enable_status then
                        next_sel := status_sel_i;
                    else
                        next_sel := lmk_ctl_sel_o;
                    end if;

                    -- If the state is unchanged we can act on any write request
                    -- immediately, otherwise we need to trigger a transition
                    if next_sel = lmk_ctl_sel_o then
                        if write_strobe_in then
                            do_write(write_ack);
                        end if;
                    else
                        -- Initiate switch to selected LMK.  Before switching
                        -- force reset and sync into quiescent states
                        lmk_ctl_sel_o <= next_sel;
                        lmk_reset_l_o <= '1';
                        lmk_sync_o <= '0';
                        start_write <= write_strobe_in;
                        switch_delay <=
                            to_unsigned(T_SWITCH, switch_delay'LENGTH);
                        write_state <= STATE_SWITCH;
                    end if;

                    -- Process reads in IDLE state
                    if read_strobe_in then
                        do_read(read_ack);
                    end if;

                when STATE_SWITCH =>
                    -- Wait for LMK selection to complete its transition
                    if switch_delay > 0 then
                        switch_delay <= switch_delay - 1;
                    elsif start_write then
                        do_write(write_ack);
                    else
                        write_state <= STATE_IDLE;
                    end if;

                when STATE_WAIT_BUSY =>
                    -- Wait for busy acknowledge from SPI engine.  Should be
                    -- immediate
                    if spi_busy_i then
                        write_state <= STATE_BUSY;
                    end if;

                when STATE_BUSY =>
                    -- Wait for SPI transaction to complete
                    spi_start_o <= '0';
                    if not spi_busy_i then
                        write_ack := '1';
                        write_state <= STATE_IDLE;
                    end if;
            end case;

            -- Keep track of writes, ensuring we don't miss any strobes while
            -- we're busy
            write_busy <= not write_ack and write_strobe_in;
            write_ack_o <= write_ack;

            -- Similarly for reads
            read_busy <= not read_ack and read_strobe_in;
            read_ack_o <= read_ack;
        end if;
    end process;

    status_idle_o <= to_std_ulogic(write_state = STATE_IDLE);
end;
