-- Register interface for training

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.gddr6_defs.all;
use work.gddr6_register_defines.all;

entity gddr6_setup_exchange is
    generic (
        MAX_DELAY : real
    );
    port (
        reg_clk_i : in std_ulogic;          -- Register clock
        ck_clk_i : in std_ulogic;       -- PHY clock
        ck_clk_ok_i : in std_ulogic;

        -- Register interface for data access
        write_strobe_i : in std_ulogic_vector(GDDR6_EXCHANGE_REGS);
        write_data_i : in reg_data_array_t(GDDR6_EXCHANGE_REGS);
        write_ack_o : out std_ulogic_vector(GDDR6_EXCHANGE_REGS);
        read_strobe_i : in std_ulogic_vector(GDDR6_EXCHANGE_REGS);
        read_data_o : out reg_data_array_t(GDDR6_EXCHANGE_REGS);
        read_ack_o : out std_ulogic_vector(GDDR6_EXCHANGE_REGS);

        enable_controller_i : in std_ulogic;
        setup_trigger_i : in std_ulogic;
        capture_edc_out_i : in std_ulogic;
        edc_select_i : in std_ulogic;

        -- PHY interface on ck_clk_i, connected to gddr6_phy
        phy_ca_o : out phy_ca_t;
        phy_ca_i : in phy_ca_t;
        phy_output_enable_i : in std_ulogic;
        phy_dq_o : out phy_dq_out_t;
        phy_dq_i : in phy_dq_in_t;
        phy_dbi_n_o : out phy_dbi_t;
        phy_dbi_n_i : in phy_dbi_t
    );
end;

architecture arch of gddr6_setup_exchange is
    signal command_bits : reg_data_t;
    signal command_ack : reg_data_t;
    signal ca_bits : reg_data_t;
    signal write_dq_strobe : std_ulogic;
    signal write_dq_ack : std_ulogic;
    signal write_dbi_strobe : std_ulogic;
    signal write_dbi_ack : std_ulogic;

    signal start_write : std_ulogic;
    signal start_read : std_ulogic;
    signal step_read : std_ulogic;
    signal write_ca_strobe : std_ulogic;

    signal exchange_strobe : std_ulogic;
    signal exchange_ack : std_ulogic;
    signal exchange_count : unsigned(5 downto 0);

    signal write_address : unsigned(5 downto 0);
    signal read_address : unsigned(5 downto 0) := (others => '0');

    signal write_dq_address : natural range 0 to 15;
    signal write_dq_buf_strobe : std_ulogic_vector(0 to 15);
    signal write_dbi_address : natural range 0 to 1;
    signal write_dbi_buf_strobe : std_ulogic_vector(0 to 1);

    signal read_dq_data : reg_data_array_t(0 to 15);
    signal read_dbi_data : reg_data_array_t(0 to 1);
    signal read_edc_data : reg_data_array_t(0 to 1);
    signal read_ca_data : reg_data_t := (others => '0');

begin
    -- COMMAND
    command : entity work.register_command port map (
        clk_i => reg_clk_i,
        write_strobe_i => write_strobe_i(GDDR6_COMMAND_REG),
        write_data_i => write_data_i(GDDR6_COMMAND_REG),
        write_ack_o => write_ack_o(GDDR6_COMMAND_REG),
        strobed_bits_o => command_bits,
        strobed_ack_i => command_ack
    );
    read_ack_o(GDDR6_COMMAND_REG) <= '1';
    read_data_o(GDDR6_COMMAND_REG) <= (others => '0');

    -- CA
    ca_bits <= write_data_i(GDDR6_CA_REG);
    write_ca_strobe <= write_strobe_i(GDDR6_CA_REG);
    write_ack_o(GDDR6_CA_REG) <= '1';
    read_ack_o(GDDR6_CA_REG) <= '1';
    read_data_o(GDDR6_CA_REG) <= read_ca_data;

    -- DQ
    read_dq : entity work.register_read_block port map (
        clk_i => reg_clk_i,
        read_strobe_i => read_strobe_i(GDDR6_DQ_REG),
        read_data_o => read_data_o(GDDR6_DQ_REG),
        read_ack_o => read_ack_o(GDDR6_DQ_REG),
        read_start_i => step_read,
        registers_i => read_dq_data
    );
    write_dq_strobe <= write_strobe_i(GDDR6_DQ_REG);
    write_ack_o(GDDR6_DQ_REG) <= write_dq_ack;


    -- DBI
    read_dbi : entity work.register_read_block port map (
        clk_i => reg_clk_i,
        read_strobe_i => read_strobe_i(GDDR6_DBI_REG),
        read_data_o => read_data_o(GDDR6_DBI_REG),
        read_ack_o => read_ack_o(GDDR6_DBI_REG),
        read_start_i => step_read,
        registers_i => read_dbi_data
    );
    write_dbi_strobe <= write_strobe_i(GDDR6_DBI_REG);
    write_ack_o(GDDR6_DBI_REG) <= write_dbi_ack;

    -- EDC
    read_edc : entity work.register_read_block port map (
        clk_i => reg_clk_i,
        read_strobe_i => read_strobe_i(GDDR6_EDC_REG),
        read_data_o => read_data_o(GDDR6_EDC_REG),
        read_ack_o => read_ack_o(GDDR6_EDC_REG),
        read_start_i => step_read,
        registers_i => read_edc_data
    );
    write_ack_o(GDDR6_EDC_REG) <= '1';


    -- Decode of command bits
    -- Actually, we have a bit of an issue here, as at present there is no
    -- handshaking for any of these commands
    start_write <= command_bits(GDDR6_COMMAND_START_WRITE_BIT);
    start_read <= command_bits(GDDR6_COMMAND_START_READ_BIT);
    step_read <= command_bits(GDDR6_COMMAND_STEP_READ_BIT);
    exchange_strobe <= command_bits(GDDR6_COMMAND_EXCHANGE_BIT);
    command_ack <= (
        GDDR6_COMMAND_EXCHANGE_BIT => exchange_ack,
        GDDR6_COMMAND_STEP_READ_BIT => step_read,
        others => '1');

    process (reg_clk_i) begin
        if rising_edge(reg_clk_i) then
            -- Write address management and strobe generation
            if enable_controller_i then
                exchange_count <= (others => '1');
            elsif start_write then
                write_address <= (others => '0');
            elsif write_ca_strobe then
                exchange_count <= write_address;
                write_address <= write_address + 1;
            end if;

            if start_write or write_ca_strobe then
                write_dq_address <= 0;
            elsif write_dq_strobe then
                write_dq_address <= write_dq_address + 1;
            end if;
            compute_strobe(
                write_dq_buf_strobe, write_dq_address, write_dq_strobe);
            write_dq_ack <= write_dq_strobe;

            if start_write or write_ca_strobe then
                write_dbi_address <= 0;
            elsif write_dbi_strobe then
                write_dbi_address <= write_dbi_address + 1;
            end if;
            compute_strobe(
                write_dbi_buf_strobe, write_dbi_address, write_dbi_strobe);
            write_dbi_ack <= write_dbi_strobe;

            -- Read address
            if start_read then
                read_address <= (others => '0');
            elsif step_read then
                read_address <= read_address + 1;
            end if;
        end if;
    end process;


    buffers : entity work.gddr6_setup_buffers generic map (
        MAX_DELAY => MAX_DELAY
    ) port map (
        reg_clk_i => reg_clk_i,
        ck_clk_i => ck_clk_i,
        ck_clk_ok_i => ck_clk_ok_i,

        exchange_strobe_i => exchange_strobe or setup_trigger_i,
        exchange_ack_o => exchange_ack,
        exchange_count_i => exchange_count,

        write_address_i => write_address,
        read_address_i => read_address,

        write_ca_strobe_i => write_ca_strobe,
        write_ca_i => (
            ca => (
                0 => ca_bits(GDDR6_CA_RISING_BITS),
                1 => ca_bits(GDDR6_CA_FALLING_BITS)),
            ca3 => reverse(ca_bits(GDDR6_CA_CA3_BITS)),
            cke_n => ca_bits(GDDR6_CA_CKE_N_BIT)),
        write_output_enable_i => ca_bits(GDDR6_CA_OUTPUT_ENABLE_BIT),

        read_ca_o.ca(0) => read_ca_data(GDDR6_CA_RISING_BITS),
        read_ca_o.ca(1) => read_ca_data(GDDR6_CA_FALLING_BITS),
        reverse(read_ca_o.ca3) => read_ca_data(GDDR6_CA_CA3_BITS),
        read_ca_o.cke_n => read_ca_data(GDDR6_CA_CKE_N_BIT),
        read_output_enable_o => read_ca_data(GDDR6_CA_OUTPUT_ENABLE_BIT),

        write_data_strobe_i => write_dq_buf_strobe,
        write_data_i => (others => write_data_i(GDDR6_DQ_REG)),

        write_dbi_strobe_i => write_dbi_buf_strobe,
        write_dbi_i => (others => write_data_i(GDDR6_DBI_REG)),

        reg_data_array_t(read_data_o) => read_dq_data,
        reg_data_array_t(read_dbi_o) => read_dbi_data,
        reg_data_array_t(read_edc_o) => read_edc_data,

        capture_edc_out_i => capture_edc_out_i,
        edc_select_i => edc_select_i,

        phy_ca_o => phy_ca_o,
        phy_ca_i => phy_ca_i,
        phy_output_enable_i => phy_output_enable_i,
        phy_dq_o => phy_dq_o,
        phy_dq_i => phy_dq_i,
        phy_dbi_n_o => phy_dbi_n_o,
        phy_dbi_n_i => phy_dbi_n_i
    );
end;
