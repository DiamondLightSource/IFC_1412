-- Read interface to CTRL

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_axi_defs.all;

entity gddr6_axi_read_ctrl is
    port (
        clk_i : in std_ulogic;

        -- AXI burst read request
        fifo_address_i : in address_t;
        fifo_ready_o : out std_ulogic := '1';

        -- A FIFO data slot must be reserved before issuing a read request
        fifo_reserve_o : out std_ulogic := '0';
        fifo_reserve_ready_i : in std_ulogic;

        -- Request to CTRL
        ctrl_address_o : out unsigned(24 downto 0);
        ctrl_valid_o : out std_ulogic := '0';
        ctrl_ready_i : in std_ulogic;

        -- Lookahead
        lookahead_address_o : out unsigned(24 downto 0);
        lookahead_count_o : out unsigned(4 downto 0);
        lookahead_valid_o : out std_ulogic := '0'
    );
end;

architecture arch of gddr6_axi_read_ctrl is
    signal next_address : address_t := IDLE_ADDRESS;
    signal address : address_t := IDLE_ADDRESS;

    signal reserve_count : unsigned(4 downto 0) := (others => '0');
    constant MAX_RESERVE_COUNT : unsigned(4 downto 0) := (others => '1');


    -- Maintain the reserve count so that we can issue commands.  There is no
    -- harm in maintaining a large reserve, and it helps with issuing lookahead
    procedure update_reserve_count(
        signal reserve_count : inout unsigned;
        signal fifo_reserve_o : inout std_ulogic;
        variable reserve_ok : out std_ulogic)
    is
        variable next_count : reserve_count'SUBTYPE;

    begin
        next_count := up_down(reserve_count,
            fifo_reserve_o and fifo_reserve_ready_i,
            ctrl_valid_o and ctrl_ready_i);

        reserve_count <= next_count;
        fifo_reserve_o <= next_count ?< MAX_RESERVE_COUNT;
        reserve_ok := next_count ?> 0;
    end;


    -- Advances or loads the output address as appropriate, sets address_ready
    -- when we're ready to load a new address
    procedure advance_address(
        reserve_ok : std_ulogic;
        signal address : inout address_t;
        signal ctrl_valid : inout std_ulogic;
        variable address_ready : out std_ulogic)
    is
        function increment_address(address : address_t) return address_t is
        begin
            assert address.count ?> 0 and address.valid severity failure;
            -- This assert indicates an AXI protocol error, not an error in
            -- the controller
            assert address.address(4 downto 0) /= 5X"1F" severity warning;
            return (
                address =>
                    -- The top 20 bits of the address are never incremented as
                    -- an AXI burst cannot cross a 4K page boundary
                    address.address(24 downto 5) &
                    (address.address(4 downto 0) + 1),
                count => address.count - 1,
                valid => '1'
            );
        end;

        -- Determines the next value for address.valid, needed for registered
        -- calculation of ctrl_valid
        variable address_valid : std_ulogic;

    begin
        -- We'll take a new address if we haven't got a valid address or when
        -- the counter has run down and our current value has been accepted
        address_ready :=
            not address.valid or
            (ctrl_ready_i and ctrl_valid and address.count ?= 0);

        address_valid := address.valid;
        if address_ready then
            address <= next_address;
            address_valid := next_address.valid;
        elsif ctrl_ready_i and ctrl_valid and address.count ?> 0 then
            address <= increment_address(address);
        end if;

        ctrl_valid <= address_valid and reserve_ok;
    end;


    -- Simple ping-pong buffer for next_address.  We maintain fifo_ready as the
    -- complement of next_address.valid
    procedure load_next_address(
        address_ready : std_ulogic;
        signal next_address : inout address_t;
        signal fifo_ready : out std_ulogic) is
    begin
        if address_ready and next_address.valid then
            next_address.valid <= '0';
            fifo_ready <= '1';
        elsif fifo_address_i.valid and not next_address.valid then
            next_address <= fifo_address_i;
            fifo_ready <= '0';
        end if;
    end;


begin
    process (clk_i)
        -- Set when an address has been loaded from next_address
        variable address_ready : std_ulogic;
        -- Set when there are enough FIFO slots reserved for a new read command
        variable reserve_ok : std_ulogic;
    begin
        if rising_edge(clk_i) then
            -- Maintain a reserve count to ensure that there is enough room in
            -- the read FIFO for each command we issue
            update_reserve_count(reserve_count, fifo_reserve_o, reserve_ok);

            -- Update address and load new address if necessar
            advance_address(reserve_ok, address, ctrl_valid_o, address_ready);

            -- Load next_address when consumed
            load_next_address(address_ready, next_address, fifo_ready_o);

            -- Maintain lookahead state
            lookahead_valid_o <=
                next_address.valid and not address_ready and
                reserve_count ?> address.count;
        end if;
    end process;

    ctrl_address_o <= address.address;
    lookahead_address_o <= next_address.address;
    lookahead_count_o <= address.count;
end;
