-- Clock crossing FIFO for Read data

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_axi_defs.all;

entity gddr6_axi_read_data_fifo is
    generic (
        DATA_FIFO_BITS : natural;
        MAX_DELAY : real
    );
    port (
        -- AXI consumer interface
        axi_clk_i : in std_ulogic;

        axi_data_o : out read_data_t := IDLE_READ_DATA;
        axi_ready_i : in std_ulogic;

        -- CTRL producer interface
        ctrl_clk_i : in std_ulogic;

        -- Two data slots must be reserved by a single reserve/ready handshake
        -- before a READ request is issued.  On completion two data strobes and
        -- one data_ok strobe must be signalled.
        ctrl_reserve_valid_o : out std_ulogic;
        ctrl_reserve_ready_i : in std_ulogic;

        -- Data from CTRL.  Two data strobes followed by an ok_valid strobe will
        -- advance the data FIFO
        ctrl_data_i : in ctrl_data_t;
        ctrl_data_valid_i : in std_ulogic;
        ctrl_data_ok_i : in std_ulogic;
        ctrl_data_ok_valid_i : in std_ulogic
    );
end;

architecture arch of gddr6_axi_read_data_fifo is
    subtype ADDRESS_RANGE is natural range DATA_FIFO_BITS - 2 downto 0;

    -- We maintain two write addresses, one for data and one for the ok flag.
    -- The ok flag is advanced by the address manager, but we have to manage the
    -- data write address separately: ok comes (slighly) after data.
    signal ok_write_address : unsigned(ADDRESS_RANGE);
    signal data_write_address : unsigned(ADDRESS_RANGE) := (others => '0');
    -- Data interleaving depends on the whether we are transferring the first or
    -- second transfer of an SG burst.
    signal write_phase : std_ulogic := '0';
    signal even_write_data : std_ulogic_vector(255 downto 0);
    signal odd_write_data : std_ulogic_vector(255 downto 0);

    -- Reading
    --
    -- The read address has two parts: full address used to access the OK flag,
    -- plus a read phase used for data interlaving
    signal read_address : unsigned(ADDRESS_RANGE);
    signal read_phase : std_ulogic := '0';
    signal read_address_valid : std_ulogic;
    -- Data as read
    signal ok_read_data : std_ulogic;
    signal even_read_data : std_ulogic_vector(255 downto 0);
    signal odd_read_data : std_ulogic_vector(255 downto 0);
    signal read_data_valid : std_ulogic := '0';
    -- Control signals for reading
    signal read_data_strobe : std_ulogic;
    signal read_ok_strobe : std_ulogic;
    signal advance_read_address : std_ulogic;

begin
    -- The clock domain crossing part of this FIFO works in steps of SG bursts
    async_address : entity work.async_fifo_address generic map (
        ADDRESS_WIDTH => DATA_FIFO_BITS - 1,
        ENABLE_WRITE_RESERVE => true,
        ENABLE_READ_RESERVE => false,
        MAX_DELAY => MAX_DELAY
    ) port map (
        write_clk_i => ctrl_clk_i,
        write_reserve_i => ctrl_reserve_ready_i,
        write_ready_o => ctrl_reserve_valid_o,
        write_access_i => ctrl_data_ok_valid_i,
        write_access_address_o => ok_write_address,

        read_clk_i => axi_clk_i,
        read_access_i => advance_read_address,
        read_valid_o => read_address_valid,
        read_access_address_o => read_address
    );

    ok_fifo : entity work.memory_array_dual generic map (
        ADDR_BITS => DATA_FIFO_BITS - 1,
        DATA_BITS => 1,
        MEM_STYLE => "DISTRIBUTED"
    ) port map (
        write_clk_i => ctrl_clk_i,
        write_strobe_i => ctrl_data_ok_valid_i,
        write_addr_i => ok_write_address,
        write_data_i(0) => ctrl_data_ok_i,

        read_clk_i => axi_clk_i,
        read_strobe_i => read_ok_strobe,
        read_addr_i => read_address,
        read_data_o(0) => ok_read_data
    );


    -- Dual FIFOs for managing data reordering.  See gddrt_axi_write_data_fifo
    -- for details

    even_fifo : entity work.memory_array_dual generic map (
        ADDR_BITS => DATA_FIFO_BITS,
        DATA_BITS => 256,
        MEM_STYLE => "BLOCK"
    ) port map (
        write_clk_i => ctrl_clk_i,
        write_strobe_i => ctrl_data_valid_i,
        write_addr_i => data_write_address & write_phase,
        write_data_i => even_write_data,

        read_clk_i => axi_clk_i,
        read_strobe_i => read_data_strobe,
        read_addr_i => read_address & read_phase,
        read_data_o => even_read_data
    );

    odd_fifo : entity work.memory_array_dual generic map (
        ADDR_BITS => DATA_FIFO_BITS,
        DATA_BITS => 256,
        MEM_STYLE => "BLOCK"
    ) port map (
        write_clk_i => ctrl_clk_i,
        write_strobe_i => ctrl_data_valid_i,
        write_addr_i => data_write_address & write_phase,
        write_data_i => odd_write_data,

        read_clk_i => axi_clk_i,
        read_strobe_i => read_data_strobe,
        read_addr_i => read_address & not read_phase,
        read_data_o => odd_read_data
    );


    process (all)
        variable data_out : ctrl_data_t;
    begin
        -- Gather incoming data in channels
        case write_phase is
            when '0' =>
                even_write_data <= ctrl_data_i(1) & ctrl_data_i(0);
                odd_write_data  <= ctrl_data_i(3) & ctrl_data_i(2);
            when '1' =>
                even_write_data <= ctrl_data_i(3) & ctrl_data_i(2);
                odd_write_data  <= ctrl_data_i(1) & ctrl_data_i(0);
            when others =>
        end case;

        -- Gather data out back into channels
        data_out := (
            0 => even_read_data(127 downto 0),
            1 => even_read_data(255 downto 128),
            2 => odd_read_data(127 downto 0),
            3 => odd_read_data(255 downto 128)
        );

        -- Generate outgoing result.  Note that, unusually, this is not
        -- registered: this is fine, as (apart from a skid buffer mux) this is
        -- going directly into a register in gddr6_axi_read_data.
        --    Note that read_phase corresponds to the phase of the *next* read
        -- as this is toggled in preparation for the next read update.
        case read_phase is
            when '1' =>
                axi_data_o.data <=
                    data_out(3) & data_out(1) & data_out(2) & data_out(0);
            when '0' =>
                axi_data_o.data <=
                    data_out(1) & data_out(3) & data_out(0) & data_out(2);
            when others =>
        end case;
        axi_data_o.ok <= ok_read_data;
        axi_data_o.valid <= read_data_valid;
    end process;


    process (ctrl_clk_i) begin
        if rising_edge(ctrl_clk_i) then
            if ctrl_data_valid_i then
                write_phase <= not write_phase;
                if write_phase = '1' then
                    data_write_address <= data_write_address + 1;
                end if;
            end if;
        end if;
    end process;


    read_data_strobe <= not read_data_valid or axi_ready_i;
    read_ok_strobe <= read_data_strobe and not read_phase;
    advance_read_address <= read_data_strobe and read_phase;

    process (axi_clk_i) begin
        if rising_edge(axi_clk_i) then
            if read_data_strobe then
                read_data_valid <= read_address_valid;
                if read_address_valid then
                    -- Toggle read_phase on successful read
                    read_phase <= not read_phase;
                end if;
            end if;
        end if;
    end process;
end;
