library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity testbench is
end testbench;

architecture arch of testbench is
    constant FIFO_WIDTH : natural := 8;
    constant CLOCK_SKEW : time := 1 ns;

    signal clk_in : std_ulogic := '0';
    signal clk_out : std_ulogic := '0';
    signal data_in : std_ulogic_vector(FIFO_WIDTH-1 downto 0)
        := (others => '0');
    signal data_out : std_ulogic_vector(FIFO_WIDTH-1 downto 0);
    signal reset : std_ulogic := '1';
    signal running : std_ulogic;

begin
    clk_in <= not clk_in after 2 ns;
    clk_out <= clk_in after CLOCK_SKEW;

    fifo : entity work.simple_fifo generic map (
        FIFO_WIDTH => FIFO_WIDTH
    ) port map (
        clk_in_i => clk_in,
        data_i => data_in,

        clk_out_i => clk_out,
        reset_i => reset,
        running_o => running,
        data_o => data_out
    );

    process (clk_in) begin
        if rising_edge(clk_in) then
            data_in <= std_ulogic_vector(signed(data_in) + 1);
        end if;
    end process;

    process begin
        reset <= '1';
        for i in 1 to 5 loop
            wait until rising_edge(clk_out);
        end loop;
        reset <= '0';
        wait;
    end process;
end;
