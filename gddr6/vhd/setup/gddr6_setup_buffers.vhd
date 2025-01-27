-- Training interface for GDDR6 PHY data exchange

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;

entity gddr6_setup_buffers is
    generic (
        MAX_DELAY : real
    );
    port (
        -- Clock for user side of FIFO
        reg_clk_i : in std_ulogic;
        -- Clock for PHY interface
        ck_clk_i : in std_ulogic;
        ck_clk_ok_i : in std_ulogic;

        -- Control interface on reg_clk_i
        exchange_strobe_i : in std_ulogic;
        exchange_ack_o : out std_ulogic;
        exchange_count_i : in unsigned(5 downto 0);

        -- All rows share the same register side write and read address
        write_address_i : in unsigned(5 downto 0);
        read_address_i : in unsigned(5 downto 0);

        -- CA loading and readback interface on reg_clk_i
        write_ca_strobe_i : in std_ulogic;
        write_ca_i : in phy_ca_t;
        write_output_enable_i : in std_ulogic;
        read_ca_o : out phy_ca_t;
        read_output_enable_o : out std_ulogic;

        -- Data loading and readback interface on reg_clk_i
        write_data_strobe_i : in std_ulogic_vector(0 to 15);
        write_data_i : in vector_array(0 to 15)(31 downto 0);

        write_dbi_strobe_i : in std_ulogic_vector(0 to 1);
        write_dbi_i : in vector_array(0 to 1)(31 downto 0);

        -- The read data becomes valid one tick after setting the address
        read_data_o : out vector_array(0 to 15)(31 downto 0);
        read_dbi_o : out vector_array(0 to 1)(31 downto 0);
        read_edc_o : out vector_array(0 to 1)(31 downto 0);

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

architecture arch of gddr6_setup_buffers is
    signal exchange_count : unsigned(5 downto 0);
    signal exchange_strobe : std_ulogic;
    signal exchange_ack : std_ulogic := '0';
    signal exchange_address : unsigned(5 downto 0) := (others => '0');
    signal exchange_active : std_ulogic := '0';

    signal dbi_capture_data : vector_array(7 downto 0)(7 downto 0);


    function to_std_ulogic_vector(value : vector_array)
        return std_ulogic_vector
    is
        -- Reassign value to a known range to simplify the loop below.  ModelSim
        -- allows me to implicitly do this assignment in the argument
        -- declaration above, but this doesn't work for Vivado.
        variable value_in : vector_array(3 downto 0)(7 downto 0);
        variable result : std_ulogic_vector(31 downto 0);
    begin
        value_in := value;
        for byte in 0 to 3 loop
            result(8*byte + 7 downto 8*byte) := value_in(byte);
        end loop;
        return result;
    end;

    function to_vector_array(
        value : std_ulogic_vector(31 downto 0)) return vector_array
    is
        variable result : vector_array(3 downto 0)(7 downto 0);
    begin
        for byte in 0 to 3 loop
            result(byte) := value(8*byte + 7 downto 8*byte);
        end loop;
        return result;
    end;

begin
    -- CA buffers
    -- Output for writing
    ca_out : entity work.memory_array_dual generic map (
        ADDR_BITS => 6,
        DATA_BITS => 26,
        INITIAL => (25 => '0', others => '1')
    ) port map (
        write_clk_i => reg_clk_i,
        write_strobe_i => write_ca_strobe_i,
        write_addr_i => write_address_i,
        write_data_i(9 downto 0) => write_ca_i.ca(0),
        write_data_i(19 downto 10) => write_ca_i.ca(1),
        write_data_i(23 downto 20) => write_ca_i.ca3,
        write_data_i(24) => write_ca_i.cke_n,
        write_data_i(25) => write_output_enable_i,

        read_clk_i => ck_clk_i,
        read_strobe_i => exchange_active,
        read_addr_i => exchange_address,
        read_data_o(9 downto 0) => phy_ca_o.ca(0),
        read_data_o(19 downto 10) => phy_ca_o.ca(1),
        read_data_o(23 downto 20) => phy_ca_o.ca3,
        read_data_o(24) => phy_ca_o.cke_n,
        read_data_o(25) => phy_dq_o.output_enable
    );

    -- Input for capture when CTRL is alive
    ca_in : entity work.memory_array_dual generic map (
        ADDR_BITS => 6,
        DATA_BITS => 26
    ) port map (
        write_clk_i => ck_clk_i,
        write_strobe_i => exchange_active,
        write_addr_i => exchange_address,
        write_data_i(9 downto 0) => phy_ca_i.ca(0),
        write_data_i(19 downto 10) => phy_ca_i.ca(1),
        write_data_i(23 downto 20) => phy_ca_i.ca3,
        write_data_i(24) => phy_ca_i.cke_n,
        write_data_i(25) => phy_output_enable_i,

        read_clk_i => reg_clk_i,
        read_addr_i => read_address_i,
        read_data_o(9 downto 0) => read_ca_o.ca(0),
        read_data_o(19 downto 10) => read_ca_o.ca(1),
        read_data_o(23 downto 20) => read_ca_o.ca3,
        read_data_o(24) => read_ca_o.cke_n,
        read_data_o(25) => read_output_enable_o
    );


    -- DQ buffers for in and out data
    gen_dq : for word in 0 to 15 generate
        subtype BYTE_RANGE is natural range 4*word + 3 downto 4*word;
    begin
        data_out : entity work.memory_array_dual generic map (
            ADDR_BITS => 6,
            DATA_BITS => 32,
            INITIAL => (others => '1')
        ) port map (
            write_clk_i => reg_clk_i,
            write_strobe_i => write_data_strobe_i(word),
            write_addr_i => write_address_i,
            write_data_i => write_data_i(word),

            read_clk_i => ck_clk_i,
            read_strobe_i => exchange_active,
            read_addr_i => exchange_address,
            to_vector_array(read_data_o) => phy_dq_o.data(BYTE_RANGE)
        );

        data_in : entity work.memory_array_dual generic map (
            ADDR_BITS => 6,
            DATA_BITS => 32
        ) port map (
            write_clk_i => ck_clk_i,
            write_strobe_i => exchange_active,
            write_addr_i => exchange_address,
            write_data_i => to_std_ulogic_vector(phy_dq_i.data(BYTE_RANGE)),

            read_clk_i => reg_clk_i,
            read_addr_i => read_address_i,
            read_data_o => read_data_o(word)
        );
    end generate;


    -- DBI buffers.  Writeable for DBI write training, captures either incoming
    -- DBI or computed EDC
    dbi_capture_data <=
        phy_dbi_n_i when not capture_edc_out_i else
        phy_dq_i.edc_write when edc_select_i else
        phy_dq_i.edc_read;
    gen_dbi : for word in 0 to 1 generate
        subtype BYTE_RANGE is natural range 4*word + 3 downto 4*word;
    begin
        dbi_out : entity work.memory_array_dual generic map (
            ADDR_BITS => 6,
            DATA_BITS => 32,
            INITIAL => (others => '1')
        ) port map (
            write_clk_i => reg_clk_i,
            write_strobe_i => write_dbi_strobe_i(word),
            write_addr_i => write_address_i,
            write_data_i => write_dbi_i(word),

            read_clk_i => ck_clk_i,
            read_strobe_i => exchange_active,
            read_addr_i => exchange_address,
            to_vector_array(read_data_o) => phy_dbi_n_o(BYTE_RANGE)
        );

        dbi_in : entity work.memory_array_dual generic map (
            ADDR_BITS => 6,
            DATA_BITS => 32
        ) port map (
            write_clk_i => ck_clk_i,
            write_strobe_i => exchange_active,
            write_addr_i => exchange_address,
            write_data_i => to_std_ulogic_vector(dbi_capture_data(BYTE_RANGE)),

            read_clk_i => reg_clk_i,
            read_addr_i => read_address_i,
            read_data_o => read_dbi_o(word)
        );
    end generate;


    -- EDC buffers, read only.  Captures EDC from memory
    gen_edc : for word in 0 to 1 generate
        subtype BYTE_RANGE is natural range 4*word + 3 downto 4*word;
    begin
        edc : entity work.memory_array_dual generic map (
            ADDR_BITS => 6,
            DATA_BITS => 32
        ) port map (
            write_clk_i => ck_clk_i,
            write_strobe_i => exchange_active,
            write_addr_i => exchange_address,
            write_data_i => to_std_ulogic_vector(phy_dq_i.edc_in(BYTE_RANGE)),

            read_clk_i => reg_clk_i,
            read_addr_i => read_address_i,
            read_data_o => read_edc_o(word)
        );
    end generate;


    -- Exchange generation
    cross_clocks : entity work.cross_clocks_write generic map (
        MAX_DELAY => MAX_DELAY
    ) port map (
        clk_in_i => reg_clk_i,
        strobe_i => exchange_strobe_i,
        ack_o => exchange_ack_o,
        data_i(5 downto 0) => std_ulogic_vector(exchange_count_i),

        clk_out_i => ck_clk_i,
        clk_out_ok_i => ck_clk_ok_i,
        strobe_o => exchange_strobe,
        ack_i => exchange_ack,
        unsigned(data_o(5 downto 0)) => exchange_count
    );

    process (ck_clk_i) begin
        if rising_edge(ck_clk_i) then
            if exchange_strobe then
                exchange_active <= '1';
                exchange_address <= (others => '0');
            elsif exchange_active then
                if exchange_address = exchange_count then
                    exchange_active <= '0';
                end if;
                exchange_address <= exchange_address + 1;
            end if;

            exchange_ack <= exchange_active and
                to_std_ulogic(exchange_address = exchange_count);
        end if;
    end process;
end;
