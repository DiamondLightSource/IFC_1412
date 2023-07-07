-- Simple IO fifo

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity simple_fifo is
    generic (
        FIFO_WIDTH : natural
    );
    port (
        clk_in_i : in std_ulogic;
        data_i : in std_ulogic_vector(FIFO_WIDTH-1 downto 0);

        clk_out_i : in std_ulogic;
        reset_i : in std_ulogic;
        running_o : out std_ulogic;
        data_o : out std_ulogic_vector(FIFO_WIDTH-1 downto 0)
    );
end;

architecture arch of simple_fifo is
    type fifo_t is array(0 to 7) of std_ulogic_vector(FIFO_WIDTH-1 downto 0);
    signal fifo : fifo_t := (others => (others => 'U'));
    signal in_ptr : unsigned(2 downto 0) := "000";
    signal out_ptr : unsigned(2 downto 0) := "000";

    signal in_ptr_sync : unsigned(2 downto 0) := "000";
    signal in_ptr_out : unsigned(2 downto 0) := "000";

    signal reset_sync : std_ulogic := '0';
    signal reset_in : std_ulogic := '0';

    attribute async_reg : string;
    attribute async_reg of in_ptr_sync : signal is "TRUE";
    attribute async_reg of in_ptr_out : signal is "TRUE";
    attribute async_reg of reset_sync : signal is "TRUE";
    attribute async_reg of reset_in : signal is "TRUE";

    signal empty_seen : boolean := false;
    signal running : std_ulogic := '0';

    function add_one(value : unsigned) return unsigned is
    begin
        case value is
            when "000" => return "001";
            when "001" => return "011";
            when "011" => return "010";
            when "010" => return "110";
            when "110" => return "111";
            when "111" => return "101";
            when "101" => return "100";
            when "100" => return "000";
            when others => return "---";
        end case;
    end;

begin
    process (clk_in_i, reset_i) begin
        if reset_i then
            reset_sync <= '1';
            reset_in <= '1';
        elsif rising_edge(clk_in_i) then
            reset_sync <= '0';
            reset_in <= reset_sync;
        end if;
    end process;

    process (clk_in_i, reset_in) begin
        if reset_in then
            in_ptr <= "000";
        elsif rising_edge(clk_in_i) then
            fifo(to_integer(in_ptr)) <= data_i;
            in_ptr <= add_one(in_ptr);
        end if;
    end process;

    process (clk_out_i, reset_i) begin
        if reset_i then
            in_ptr_out <= "000";
            out_ptr <= "000";
            running <= '0';
            empty_seen <= true;
        elsif rising_edge(clk_out_i) then
            in_ptr_sync <= in_ptr;
            in_ptr_out <= in_ptr_sync;
            empty_seen <= out_ptr = in_ptr_out;
            if running then
                out_ptr <= add_one(out_ptr);
            elsif not empty_seen then
                running <= '1';
            end if;
        end if;
    end process;

    data_o <= fifo(to_integer(out_ptr));
    running_o <= running;
end;
