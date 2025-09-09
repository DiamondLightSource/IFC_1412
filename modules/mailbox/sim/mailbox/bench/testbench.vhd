library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.register_defs.all;
use work.mailbox_register_defines.all;
use work.sim_support.all;

entity testbench is
end testbench;


architecture arch of testbench is
    constant MB_ADDRESS : std_ulogic_vector(6 downto 0) := 7X"55";

    signal clk : std_ulogic := '0';

    procedure clk_wait(count : natural := 1) is
    begin
        clk_wait(clk, count);
    end;

    signal write_strobe : std_ulogic;
    signal write_data : reg_data_t;
    signal write_ack : std_ulogic;
    signal read_strobe : std_ulogic;
    signal read_data : reg_data_t;
    signal read_ack : std_ulogic;

    signal scl : std_logic;
    signal sda : std_logic;
    signal i2c_done : std_ulogic;

    signal slot : unsigned(3 downto 0);

begin
    clk <= not clk after 2 ns;


    mailbox : entity work.mailbox generic map (
        MB_ADDRESS => MB_ADDRESS
    ) port map (
        clk_i => clk,

        write_strobe_i => write_strobe,
        write_data_i => write_data,
        write_ack_o => write_ack,
        read_strobe_i => read_strobe,
        read_data_o => read_data,
        read_ack_o => read_ack,

        scl_i => to_x01(scl),
        sda_io => sda,

        slot_o => slot
    );


    -- Simulation of MMC master
    i2c_master : entity work.i2c_master generic map (
        MB_ADDRESS => MB_ADDRESS
    ) port map (
        scl_io => scl,
        sda_io => sda,
        done_o => i2c_done
    );


    -- Register interface to mailbox
    process
        procedure write_reg(
            address : std_ulogic_vector(10 downto 0);
            data : std_ulogic_vector(7 downto 0)) is
        begin
            write_reg(clk, write_data, write_strobe, write_ack, (
                MAILBOX_ADDRESS_BITS => address,
                MAILBOX_DATA_BITS => data,
                MAILBOX_WRITE_BIT => '1',
                others => '0'), quiet => true);
            write("MB[" & to_hstring(address) & "] <= " & to_hstring(data),
                stamp => true);
        end;

        procedure read_reg_result(
            address : std_ulogic_vector(10 downto 0);
            variable result : out std_ulogic_vector;
            quiet : boolean := false)
        is
            variable value : reg_data_t;
        begin
            write_reg(clk, write_data, write_strobe, write_ack, (
                MAILBOX_ADDRESS_BITS => address,
                MAILBOX_WRITE_BIT => '0',
                others => '0'), quiet => true);
            read_reg_result(
                clk, read_data, read_strobe, read_ack, value,
                quiet => true);
            result := value(MAILBOX_DATA_BITS);
            if not quiet then
                write("MB[" & to_hstring(address) & "] => " &
                    to_hstring(result) & " slot: " &
                    to_hstring(value(MAILBOX_SLOT_BITS)),
                    stamp => true);
            end if;
        end;

        procedure read_reg(address : std_ulogic_vector(10 downto 0)) is
            variable result : std_ulogic_vector(7 downto 0);
        begin
            read_reg_result(address, result);
        end;

        variable i2c_value : std_ulogic_vector(7 downto 0);

    begin
        write_strobe <= '0';
        read_strobe <= '0';

        clk_wait(100);

        write_reg(11X"012", X"23");

        clk_wait(5);
        read_reg(11X"012");

        -- Now wait for I2C to complete
        wait until i2c_done;
        clk_wait;

        -- Read the slot number, should be 4
        read_reg_result(11X"008", i2c_value);
        write("I2C[8] = " & to_hstring(i2c_value));

        wait;
    end process;
end;
