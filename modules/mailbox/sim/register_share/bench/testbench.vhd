library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.sim_support.all;

entity testbench is
end testbench;


architecture arch of testbench is
    signal clk : std_ulogic := '0';

    procedure clk_wait(count : natural := 1) is
    begin
        clk_wait(clk, count);
    end;

    constant COUNT : natural := 2;
    constant ADDRESS_WIDTH : natural := 8;
    constant DATA_WIDTH : natural := 8;

    signal mux_address : unsigned_array(0 to COUNT-1)(ADDRESS_WIDTH-1 downto 0);
    signal mux_data_in : vector_array(0 to COUNT-1)(DATA_WIDTH-1 downto 0);
    signal mux_data_out : vector_array(0 to COUNT-1)(DATA_WIDTH-1 downto 0);
    signal mux_strobe : std_ulogic_vector(0 to COUNT-1);
    signal mux_ack : std_ulogic_vector(0 to COUNT-1);

    signal shared_address : unsigned(ADDRESS_WIDTH-1 downto 0);
    signal shared_strobe : std_ulogic;
    signal shared_data_in : std_ulogic_vector(DATA_WIDTH-1 downto 0);
    signal shared_data_out : std_ulogic_vector(DATA_WIDTH-1 downto 0);
    signal shared_ack : std_ulogic;

    procedure send(
        address : unsigned; data : std_ulogic_vector;
        signal mux_address : out unsigned;
        signal mux_data_in : out std_ulogic_vector;
        signal mux_strobe : out std_ulogic;
        signal mux_ack : in std_ulogic;
        signal mux_data_out : in std_ulogic_vector)
    is
    begin
        mux_address <= address;
        mux_data_in <= data;
        mux_strobe <= '1';
        clk_wait;
        mux_strobe <= '0';
        while not mux_ack loop
            clk_wait;
        end loop;
        mux_address <= (mux_address'RANGE => 'U');
        mux_data_in <= (mux_data_in'RANGE => 'U');
        write("TX " &
            to_hstring(address) & " " & to_hstring(data) & " => " &
            to_hstring(mux_data_out));
    end;

begin
    clk <= not clk after 2 ns;

    share : entity work.register_share generic map (
        COUNT => COUNT,
        ADDRESS_WIDTH => ADDRESS_WIDTH,
        DATA_WIDTH => DATA_WIDTH
    ) port map (
        clk_i => clk,

        mux_address_i => mux_address,
        mux_data_i => mux_data_in,
        mux_data_o => mux_data_out,
        mux_strobe_i => mux_strobe,
        mux_ack_o => mux_ack,

        shared_address_o => shared_address,
        shared_strobe_o => shared_strobe,
        shared_data_i => shared_data_in,
        shared_data_o => shared_data_out,
        shared_ack_i => shared_ack
    );


    process
        variable counter : natural := 0;
        variable delay : natural := 0;

        procedure send is
        begin
            send(X"55", X"3" & to_std_ulogic_vector_u(counter, 4),
                mux_address(0), mux_data_in(0), mux_strobe(0),
                mux_ack(0), mux_data_out(0));
            counter := counter + 1;
        end;

    begin
        mux_address(0) <= (others => 'U');
        mux_data_in(0) <= (others => 'U');
        mux_strobe(0) <= '0';

        clk_wait(2);
        -- Send with increasing delay
        loop
            send;
            clk_wait(delay);
            delay := delay + 1;
        end loop;

        wait;
    end process;


    process
        variable counter : natural := 0;

        procedure send is
        begin
            send(X"99", X"9" & to_std_ulogic_vector_u(counter, 4),
                mux_address(1), mux_data_in(1), mux_strobe(1),
                mux_ack(1), mux_data_out(1));
            counter := counter + 1;
        end;

    begin
        mux_address(1) <= (others => 'U');
        mux_data_in(1) <= (others => 'U');
        mux_strobe(1) <= '0';

        clk_wait(2);

        -- This process just sends as fast as it is allowed
        loop
            send;
        end loop;

        wait;
    end process;


    process
        variable counter : natural := 0;

        procedure receive(delay : natural := 0) is
        begin
            while not shared_strobe loop
                clk_wait;
            end loop;
            clk_wait(delay);
            shared_data_in <= to_std_ulogic_vector_u(counter, 8);
            shared_ack <= '1';
            clk_wait;
            write("RX " & to_hstring(shared_address) & " " &
                to_hstring(shared_data_out) & " => " &
                to_hstring(shared_data_in));
            shared_ack <= '0';
            shared_data_in <= (others => 'U');
            counter := counter + 1;
        end;

        procedure fast_receive is
        begin
            shared_ack <= '1';
            shared_data_in <= to_std_ulogic_vector_u(counter, 8);
            while not shared_strobe loop
                clk_wait;
            end loop;
            clk_wait;
            write("RX " & to_hstring(shared_address) & " " &
                to_hstring(shared_data_out) & " => " &
                to_hstring(shared_data_in));
            shared_data_in <= (others => 'U');
            counter := counter + 1;
        end;

    begin
        shared_data_in <= (others => 'U');
        shared_ack <= '0';

--         receive(X"45");
--         receive(X"12");
        for i in 0 to 7 loop
            receive;
        end loop;

        loop
            fast_receive;
        end loop;

        wait;
    end process;
end;
