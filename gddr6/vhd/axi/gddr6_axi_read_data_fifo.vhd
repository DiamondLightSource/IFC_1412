-- Clock crossing FIFO for Read data

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity gddr6_axi_read_data_fifo is
    generic (
        FIFO_BITS : natural := 10
    );
    port (
        -- AXI consumer interface
        axi_clk_i : in std_ulogic;

        axi_data_o : out std_logic_vector(511 downto 0);
        axi_data_ok_o : out std_ulogic;
        axi_valid_o : out std_ulogic := '0';
        axi_ready_i : in std_ulogic;

        -- CTRL producer interface
        ctrl_clk_i : in std_ulogic;

        -- Two data slots must be reserved by a single reserve/ready handshake
        -- before a READ request is issued.  On completion two data strobes and
        -- one data_ok strobe must be signalled.
        ctrl_reserve_i : in std_ulogic;
        ctrl_reserve_ready_o : out std_ulogic;

        -- Data from CTRL.  Two data strobes followed by an ok_valid strobe will
        -- advance the data FIFO
        ctrl_data_i : in vector_array(0 to 3)(127 downto 0);
        ctrl_data_valid_i : in std_ulogic;
        ctrl_data_ok_i : in std_ulogic;
        ctrl_data_ok_valid_i : in std_ulogic
    );
end;

architecture arch of gddr6_axi_read_data_fifo is
    -- We maintain two write addresses, one for data and one for the ok flag.
    -- The ok flag is advanced by the address manager, but we have to manage the
    -- data write address separately: ok comes (slighly) after data.
    signal ok_write_address : unsigned(FIFO_BITS-2 downto 0);
    signal data_write_address : unsigned(FIFO_BITS-2 downto 0)
        := (others => '0');
    signal read_address : unsigned(FIFO_BITS-2 downto 0)
        := (others => '0');

    -- Three separate FIFO buffers: one for the OK flags, and two separate FIFOs
    -- to support data interleaving
    subtype SG_FIFO_RANGE is natural range 0 to 2**(FIFO_BITS-1) - 1;
    subtype DATA_FIFO_RANGE is natural range 0 to 2**FIFO_BITS - 1;
    signal ok_fifo : std_ulogic_vector(SG_FIFO_RANGE);
    signal even_data_fifo : vector_array(DATA_FIFO_RANGE)(255 downto 0);
    signal odd_data_fifo  : vector_array(DATA_FIFO_RANGE)(255 downto 0);

    -- Data interleaving depends on the whether we are transferring the first or
    -- second transfer of an SG burst.
    signal write_phase : std_ulogic := '0';
    signal read_phase : std_ulogic := '0';

    signal read_fifo_enable : std_ulogic;
    signal read_fifo_ready : std_ulogic;

begin
    -- The clock domain crossing part of this FIFO works in steps of SG bursts
    async_address : entity work.async_fifo_address generic map (
        ADDRESS_WIDTH => FIFO_BITS - 1,
        ENABLE_READ_RESERVE => false,
        ENABLE_WRITE_RESERVE => true
    ) port map (
        write_clk_i => ctrl_clk_i,
        write_reserve_i => ctrl_reserve_i,
        write_access_i => ctrl_data_ok_valid_i,
        write_ready_o => ctrl_reserve_ready_o,
        write_access_address_o => ok_write_address,

        read_clk_i => axi_clk_i,
        read_access_i => read_fifo_enable,
        read_ready_o => read_fifo_ready,
        read_access_address_o => read_address
    );


    read_fifo_enable <= (axi_ready_i or not axi_valid_o) and read_phase;
    process (axi_clk_i)
        variable address : natural;
        variable data_out : vector_array(0 to 3)(127 downto 0);

    begin
        if rising_edge(axi_clk_i) then
            -- Gather data out back into channels
            address := to_integer(read_address & read_phase);
            data_out := (
                0 => even_data_fifo(address)(127 downto 0),
                1 => even_data_fifo(address)(255 downto 128),
                2 => odd_data_fifo (address)(127 downto 0),
                3 => odd_data_fifo (address)(255 downto 128));

            if axi_ready_i or not axi_valid_o then
                if read_fifo_ready then
                    case read_phase is
                        when '0' =>
                            axi_data_o <=
                                data_out(3) & data_out(1) &
                                data_out(2) & data_out(0);
                            read_phase <= '1';
                        when '1' =>
                            axi_data_o <=
                                data_out(2) & data_out(0) &
                                data_out(3) & data_out(1);
                            read_phase <= '0';
                        when others =>
                    end case;
                    axi_data_ok_o <= ok_fifo(to_integer(read_address));
                    axi_valid_o <= '1';
                else
                    axi_valid_o <= '0';
                end if;
            end if;
        end if;
    end process;


    process (ctrl_clk_i)
        impure function address(phase : std_ulogic) return natural is
        begin
            return to_integer(data_write_address & phase);
        end;

    begin
        if rising_edge(ctrl_clk_i) then
            if ctrl_data_ok_valid_i then
                ok_fifo(to_integer(ok_write_address)) <= ctrl_data_ok_i;
            end if;

            if ctrl_data_valid_i then
                case write_phase is
                    when '0' =>
                        even_data_fifo(address('0')) <=
                            ctrl_data_i(1) & ctrl_data_i(0);
                        odd_data_fifo(address('1')) <=
                            ctrl_data_i(3) & ctrl_data_i(2);
                        write_phase <= '1';
                    when '1' =>
                        even_data_fifo(address('1')) <=
                            ctrl_data_i(3) & ctrl_data_i(2);
                        odd_data_fifo(address('0')) <=
                            ctrl_data_i(1) & ctrl_data_i(0);
                        write_phase <= '0';
                        data_write_address <= data_write_address + 1;
                    when others =>
                end case;
            end if;
        end if;
    end process;
end;
