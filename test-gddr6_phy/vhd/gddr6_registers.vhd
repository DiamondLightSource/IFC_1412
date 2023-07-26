-- Register interface to GDDR6 PHY

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.register_defines.all;

entity gddr6_registers is
    port (
        clk_i : in std_ulogic;

        -- System register interface
        write_strobe_i : in std_ulogic_vector(PHY_REGS_RANGE);
        write_data_i : in reg_data_array_t(PHY_REGS_RANGE);
        write_ack_o : out std_ulogic_vector(PHY_REGS_RANGE);
        read_strobe_i : in std_ulogic_vector(PHY_REGS_RANGE);
        read_data_o : out reg_data_array_t(PHY_REGS_RANGE);
        read_ack_o : out std_ulogic_vector(PHY_REGS_RANGE);

        ck_unlock_i : in std_ulogic;
        fifo_ok_i : in std_ulogic;

        sg_resets_o : out std_ulogic_vector(0 to 1);
        enable_cabi_o : out std_ulogic;
        enable_dbi_o : out std_ulogic;
        dq_t_o : out std_ulogic;

        ca_o : out vector_array(0 to 1)(9 downto 0);
        ca3_o : out std_ulogic_vector(0 to 3);
        cke_n_o : out std_ulogic;

        dq_data_i : in std_ulogic_vector(511 downto 0);
        dq_data_o : out std_ulogic_vector(511 downto 0);
        edc_in_i : in vector_array(7 downto 0)(7 downto 0);
        edc_out_i : in vector_array(7 downto 0)(7 downto 0);

        riu_addr_o : out unsigned(9 downto 0);
        riu_wr_data_o : out std_ulogic_vector(15 downto 0);
        riu_rd_data_i : in std_ulogic_vector(15 downto 0);
        riu_wr_en_o : out std_ulogic;
        riu_strobe_o : out std_ulogic;
        riu_ack_i : in std_ulogic
    );
end;

architecture arch of gddr6_registers is
    signal event_bits : reg_data_t;
    signal status_bits : reg_data_t;
    signal config_bits : reg_data_t;
    signal edc_in_bits : reg_data_array_t(0 to 1);
    signal edc_out_bits : reg_data_array_t(0 to 1);
    signal data_in_bits : reg_data_array_t(0 to 15);
    signal data_out_bits : reg_data_array_t(0 to 15);
    signal riu_bits_in : reg_data_t;
    signal riu_bits_out : reg_data_t;

begin
    -- IDENT
    read_data_o(PHY_IDENT_REG) <= to_std_ulogic_vector_u(PHY_MAGIC_NUMBER, 32);
    read_ack_o(PHY_IDENT_REG) <= '1';
    write_ack_o(PHY_IDENT_REG) <= '1';

    -- EVENTS
    events :  entity work.register_events port map (
        clk_i => clk_i,
        read_strobe_i => read_strobe_i(PHY_EVENTS_REG),
        read_data_o => read_data_o(PHY_EVENTS_REG),
        read_ack_o => read_ack_o(PHY_EVENTS_REG),
        pulsed_bits_i => event_bits
    );
    write_ack_o(PHY_EVENTS_REG) <= '1';

    -- STATUS
    read_data_o(PHY_STATUS_REG) <= status_bits;
    read_ack_o(PHY_STATUS_REG) <= '1';
    write_ack_o(PHY_STATUS_REG) <= '1';

    -- CONFIG
    config : entity work.register_file_rw port map (
        clk_i => clk_i,
        write_strobe_i(0) => write_strobe_i(PHY_CONFIG_REG),
        write_data_i(0) => write_data_i(PHY_CONFIG_REG),
        write_ack_o(0) => write_ack_o(PHY_CONFIG_REG),
        read_strobe_i(0) => read_strobe_i(PHY_CONFIG_REG),
        read_data_o(0) => read_data_o(PHY_CONFIG_REG),
        read_ack_o(0) => read_ack_o(PHY_CONFIG_REG),
        register_data_o(0) => config_bits
    );

    -- CA
    ca : entity work.write_ca port map (
        clk_i => clk_i,
        write_strobe_i => write_strobe_i(PHY_CA_REG),
        write_data_i => write_data_i(PHY_CA_REG),
        write_ack_o => write_ack_o(PHY_CA_REG),
        ca_o => ca_o,
        ca3_o => ca3_o,
        cke_n_o => cke_n_o
    );
    read_data_o(PHY_CA_REG) <= (others => '0');
    read_ack_o(PHY_CA_REG) <= '1';

    -- DQ
    dq_write : entity work.register_file port map (
        clk_i => clk_i,
        write_strobe_i => write_strobe_i(PHY_DQ_REGS),
        write_data_i => write_data_i(PHY_DQ_REGS),
        write_ack_o => write_ack_o(PHY_DQ_REGS),
        register_data_o => data_out_bits
    );
    read_data_o(PHY_DQ_REGS) <= data_in_bits;
    read_ack_o(PHY_DQ_REGS) <= (others => '1');

    -- EDC_IN
    read_data_o(PHY_EDC_IN_REGS) <= edc_in_bits;
    read_ack_o(PHY_EDC_IN_REGS) <= (others => '1');
    write_ack_o(PHY_EDC_IN_REGS) <= (others => '1');

    -- EDC_OUT
    read_data_o(PHY_EDC_OUT_REGS) <= edc_out_bits;
    read_ack_o(PHY_EDC_OUT_REGS) <= (others => '1');
    write_ack_o(PHY_EDC_OUT_REGS) <= (others => '1');

    -- RIU
    riu_bits_out <= write_data_i(PHY_RIU_REG);
    riu_strobe_o <= write_strobe_i(PHY_RIU_REG);
    write_ack_o(PHY_RIU_REG) <= riu_ack_i;
    read_data_o(PHY_RIU_REG) <= riu_bits_in;
    read_ack_o(PHY_RIU_REG) <= '1';


    -- -------------------------------------------------------------------------

    -- EVENTS
    event_bits <= (
        PHY_EVENTS_CK_UNLOCK_BIT => ck_unlock_i,
        PHY_EVENTS_FIFO_DROPOUT_BIT => not fifo_ok_i,
        others => '0'
    );

    -- STATUS
    status_bits <= (
        PHY_STATUS_FIFO_OK_BIT => fifo_ok_i,
        others => '0'
    );

    -- CONFIG
    sg_resets_o <= config_bits(PHY_CONFIG_SG_RESET_N_BITS);
    enable_cabi_o <= config_bits(PHY_CONFIG_ENABLE_CABI_BIT);
    enable_dbi_o <= config_bits(PHY_CONFIG_ENABLE_DBI_BIT);
    dq_t_o <= config_bits(PHY_CONFIG_DQ_T_BIT);

    -- EDC_IN, EDC_OUT
    gen_edc : for i in 0 to 7 generate
        constant word : natural := i / 4;
        constant byte : natural := i mod 4;
        subtype BYTE_RANGE is natural range 8*byte + 7 downto 8*byte;
    begin
        edc_in_bits(word)(BYTE_RANGE) <= edc_in_i(i);
        edc_out_bits(word)(BYTE_RANGE) <= edc_out_i(i);
    end generate;

    -- DQ
    gen_dq : for i in 0 to 15 generate
        subtype WORD_RANGE is natural range 32*i + 31 downto 32*i;
    begin
        data_in_bits(i) <= dq_data_i(WORD_RANGE);
        dq_data_o(WORD_RANGE) <= data_out_bits(i);
    end generate;

    -- RIU
    riu_addr_o <= unsigned(riu_bits_out(PHY_RIU_ADDRESS_BITS));
    riu_wr_data_o <= riu_bits_out(PHY_RIU_DATA_BITS);
    riu_wr_en_o <= riu_bits_out(PHY_RIU_WRITE_BIT);
    process (clk_i) begin
        if rising_edge(clk_i) then
            if riu_ack_i then
                riu_bits_in <= (
                    PHY_RIU_DATA_BITS => std_ulogic_vector(riu_rd_data_i),
                    others => '0'
                );
            end if;
        end if;
    end process;
end;
