-- Configuration and monitoring

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.gddr6_register_defines.all;

entity gddr6_setup_control is
    port (
        ck_clk_i : in std_ulogic;       -- CK clock
        ck_clk_ok_i : in std_ulogic;    -- CK and RIU clocks ok
        reg_clk_i : in std_ulogic;      -- Register clock

        -- Register interface for data access
        write_strobe_i : in std_ulogic_vector(GDDR6_CONTROL_REGS);
        write_data_i : in reg_data_array_t(GDDR6_CONTROL_REGS);
        write_ack_o : out std_ulogic_vector(GDDR6_CONTROL_REGS);
        read_strobe_i : in std_ulogic_vector(GDDR6_CONTROL_REGS);
        read_data_o : out reg_data_array_t(GDDR6_CONTROL_REGS);
        read_ack_o : out std_ulogic_vector(GDDR6_CONTROL_REGS);

        -- Controls to PHY.  All except ck_reset_o on CK clock
        ck_reset_o : out std_ulogic;
        ck_unlock_i : in std_ulogic;
        fifo_ok_i : in std_ulogic;
        sg_resets_n_o : out std_ulogic_vector(0 to 1) := "00";

        -- General PHY configuration on CK clock
        enable_cabi_o : out std_ulogic;
        enable_dbi_o : out std_ulogic;
        rx_slip_o : out unsigned_array(0 to 1)(2 downto 0);
        tx_slip_o : out unsigned_array(0 to 1)(2 downto 0)

        -- Further controls will be below
    );
end;

architecture arch of gddr6_setup_control is
    signal control_bits_reg : reg_data_t;
    signal control_bits_ck : reg_data_t;
    signal status_bits_reg : reg_data_t;

    signal ck_unlock_ck : std_ulogic := '0';
    signal ck_unlock_reg : std_ulogic;
    signal fifo_ok_reg : std_ulogic;
    signal reset_ck_events : std_ulogic;

    -- False paths to the appropriate clock crossing registers
    attribute FALSE_PATH_TO : string;
    attribute FALSE_PATH_TO of control_bits_ck : signal is "TRUE";
    attribute FALSE_PATH_TO of ck_unlock_reg : signal is "TRUE";
    attribute FALSE_PATH_TO of fifo_ok_reg : signal is "TRUE";
    attribute FALSE_PATH_FROM : string;
    attribute FALSE_PATH_FROM of ck_reset_o : signal is "TRUE";
    attribute KEEP : string;
    attribute KEEP of control_bits_ck : signal is "TRUE";
    attribute KEEP of ck_unlock_reg : signal is "TRUE";
    attribute KEEP of fifo_ok_reg : signal is "TRUE";
    attribute KEEP of ck_reset_o : signal is "TRUE";

begin
    control : entity work.register_file_rw port map (
        clk_i => reg_clk_i,

        write_strobe_i(0) => write_strobe_i(GDDR6_CONFIG_REG),
        write_data_i(0) => write_data_i(GDDR6_CONFIG_REG),
        write_ack_o(0) => write_ack_o(GDDR6_CONFIG_REG),
        read_strobe_i(0) => read_strobe_i(GDDR6_CONFIG_REG),
        read_data_o(0) => read_data_o(GDDR6_CONFIG_REG),
        read_ack_o(0) => read_ack_o(GDDR6_CONFIG_REG),

        register_data_o(0) => control_bits_reg
    );

    write_ack_o(GDDR6_STATUS_REG) <= '1';
    read_ack_o(GDDR6_STATUS_REG) <= '1';
    read_data_o(GDDR6_STATUS_REG) <= status_bits_reg;


    -- Use read strobe for status register to reset unlock register
    strobe : entity work.sync_pulse port map (
        clk_in_i => reg_clk_i,
        clk_out_i => ck_clk_i,
        pulse_i => read_strobe_i(GDDR6_STATUS_REG),
        pulse_o => reset_ck_events
    );


    process (ck_clk_i) begin
        if rising_edge(ck_clk_i) then
            control_bits_ck <= control_bits_reg;

            sg_resets_n_o <=
                reverse(control_bits_ck(GDDR6_CONFIG_SG_RESET_N_BITS));
            enable_cabi_o <= control_bits_ck(GDDR6_CONFIG_ENABLE_CABI_BIT);
            enable_dbi_o <= control_bits_ck(GDDR6_CONFIG_ENABLE_DBI_BIT);
            rx_slip_o <= (
                0 => unsigned(control_bits_ck(GDDR6_CONFIG_RX_SLIP_LOW_BITS)),
                1 => unsigned(control_bits_ck(GDDR6_CONFIG_RX_SLIP_HIGH_BITS)));
            tx_slip_o <= (
                0 => unsigned(control_bits_ck(GDDR6_CONFIG_TX_SLIP_LOW_BITS)),
                1 => unsigned(control_bits_ck(GDDR6_CONFIG_TX_SLIP_HIGH_BITS)));

            -- Capture unlock events until read
            if ck_unlock_i then
                ck_unlock_ck <= '1';
            elsif reset_ck_events then
                ck_unlock_ck <= '0';
            end if;
        end if;
    end process;


    process (reg_clk_i) begin
        if rising_edge(reg_clk_i) then
            ck_reset_o <= not control_bits_reg(GDDR6_CONFIG_CK_RESET_N_BIT);

            -- Clock domain crossed without ceremony
            ck_unlock_reg <= ck_unlock_ck;
            fifo_ok_reg <= fifo_ok_i;

            status_bits_reg <= (
                GDDR6_STATUS_CK_OK_BIT => ck_clk_ok_i,
                GDDR6_STATUS_CK_UNLOCK_BIT => ck_unlock_reg,
                GDDR6_STATUS_FIFO_OK_BIT => fifo_ok_reg,
                others => '0');
        end if;
    end process;
end;
