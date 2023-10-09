-- Register interface for training

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.gddr6_register_defines.all;

entity gddr6_setup_exchange is
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

        -- PHY interface on ck_clk_i, connected to gddr6_phy
        phy_ca_o : out vector_array(0 to 1)(9 downto 0);
        phy_ca3_o : out std_ulogic_vector(0 to 3);
        phy_cke_n_o : out std_ulogic_vector(0 to 1);
        phy_output_enable_o : out std_ulogic;
        phy_data_o : out std_ulogic_vector(511 downto 0);
        phy_data_i : in std_ulogic_vector(511 downto 0);
        phy_edc_in_i : in vector_array(7 downto 0)(7 downto 0);
        phy_edc_out_i : in vector_array(7 downto 0)(7 downto 0)
    );
end;

architecture arch of gddr6_setup_exchange is
    signal command_bits : reg_data_t;
    signal command_ack : reg_data_t;
    signal ca_bits : reg_data_t;
    signal write_dq_strobe : std_ulogic;
    signal write_dq_ack : std_ulogic;

    signal start_write : std_ulogic;
    signal start_read : std_ulogic;
    signal step_read : std_ulogic;
    signal write_ca_strobe : std_ulogic;

    signal exchange_strobe : std_ulogic;
    signal exchange_ack : std_ulogic;
    signal exchange_count : unsigned(5 downto 0);

    signal write_address : unsigned(5 downto 0);
    signal write_word_address : natural range 0 to 15;
    signal write_data_strobe : std_ulogic_vector(0 to 15);

    signal read_address : unsigned(5 downto 0) := (others => '0');
    signal read_dq_data : reg_data_array_t(0 to 15);
    signal read_edc_in_data : reg_data_array_t(0 to 1);
    signal read_edc_out_data : reg_data_array_t(0 to 1);

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
    read_data_o(GDDR6_CA_REG) <= (others => '0');

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


    -- EDC_IN
    read_edc_in : entity work.register_read_block port map (
        clk_i => reg_clk_i,
        read_strobe_i => read_strobe_i(GDDR6_EDC_IN_REG),
        read_data_o => read_data_o(GDDR6_EDC_IN_REG),
        read_ack_o => read_ack_o(GDDR6_EDC_IN_REG),
        read_start_i => step_read,
        registers_i => read_edc_in_data
    );
    write_ack_o(GDDR6_EDC_IN_REG) <= '1';

    -- EDC_OUT
    read_edc_out : entity work.register_read_block port map (
        clk_i => reg_clk_i,
        read_strobe_i => read_strobe_i(GDDR6_EDC_OUT_REG),
        read_data_o => read_data_o(GDDR6_EDC_OUT_REG),
        read_ack_o => read_ack_o(GDDR6_EDC_OUT_REG),
        read_start_i => step_read,
        registers_i => read_edc_out_data
    );
    write_ack_o(GDDR6_EDC_OUT_REG) <= '1';


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
            if start_write then
                write_address <= (others => '0');
                write_word_address <= 0;
            elsif write_ca_strobe then
                exchange_count <= write_address;
                write_address <= write_address + 1;
                write_word_address <= 0;
            elsif write_dq_strobe then
                write_word_address <= write_word_address + 1;
            end if;
            compute_strobe(
                write_data_strobe, write_word_address, write_dq_strobe);
            write_dq_ack <= write_dq_strobe;

            -- Read address
            if start_read then
                read_address <= (others => '0');
            elsif step_read then
                read_address <= read_address + 1;
            end if;
        end if;
    end process;


    buffers : entity work.gddr6_setup_buffers port map (
        reg_clk_i => reg_clk_i,
        ck_clk_i => ck_clk_i,
        ck_clk_ok_i => ck_clk_ok_i,

        exchange_strobe_i => exchange_strobe,
        exchange_ack_o => exchange_ack,
        exchange_count_i => exchange_count,

        write_ca_strobe_i => write_ca_strobe,
        write_ca_address_i => write_address,
        write_ca_i => (
            0 => ca_bits(GDDR6_CA_RISING_BITS),
            1 => ca_bits(GDDR6_CA_FALLING_BITS)),
        write_ca3_i => reverse(ca_bits(GDDR6_CA_CA3_BITS)),
        write_cke_n_i => reverse(ca_bits(GDDR6_CA_CKE_N_BITS)),
        write_output_enable_i => ca_bits(GDDR6_CA_OUTPUT_ENABLE_BIT),

        write_data_strobe_i => write_data_strobe,
        write_data_address_i => write_address,
        write_data_i => (others => write_data_i(GDDR6_DQ_REG)),

        read_data_address_i => read_address,
        reg_data_array_t(read_data_o) => read_dq_data,
        reg_data_array_t(read_edc_in_o) => read_edc_in_data,
        reg_data_array_t(read_edc_out_o) => read_edc_out_data,

        phy_ca_o => phy_ca_o,
        phy_ca3_o => phy_ca3_o,
        phy_cke_n_o => phy_cke_n_o,
        phy_output_enable_o => phy_output_enable_o,
        phy_data_o => phy_data_o,
        phy_data_i => phy_data_i,
        phy_edc_in_i => phy_edc_in_i,
        phy_edc_out_i => phy_edc_out_i
    );
end;
