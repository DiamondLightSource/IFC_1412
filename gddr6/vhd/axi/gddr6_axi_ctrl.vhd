-- Read/Write interface to CTRL

-- Converts SG address request into outgoing CTRL requests after ensuring that
-- the appropriate FIFO entries are reserved.  Byte mask support and response
-- reservation is not required for reads.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.flow_control.all;

use work.gddr6_defs.all;
use work.gddr6_axi_defs.all;

entity gddr6_axi_ctrl is
    port (
        clk_i : in std_ulogic;

        -- AXI transfer request in SG bursts
        address_i : in address_t;
        address_ready_o : out std_ulogic := '1';

        -- The byte mask is available when data is available for writes, and
        -- can simply be ignored for reads
        byte_mask_i : in std_ulogic_vector(127 downto 0) := (others => '0');
        byte_mask_valid_i : in std_ulogic := '1';
        byte_mask_ready_o : out std_ulogic := '1';

        -- A FIFO result slot must be reserved before issuing a request: think
        -- the reservation slot flowing from the FIFO to here
        reserve_valid_i : in std_ulogic;
        reserve_ready_o : out std_ulogic := '1';

        -- Request to CTRL
        ctrl_address_o : out unsigned(24 downto 0) := (others => '0');
        ctrl_byte_mask_o : out std_ulogic_vector(127 downto 0)
            := (others => '0');
        ctrl_valid_o : out std_ulogic := '0';
        ctrl_ready_i : in std_ulogic;

        -- Lookahead to CTRL
        lookahead_address_o : out unsigned(24 downto 0);
        lookahead_count_o : out unsigned(4 downto 0);
        lookahead_valid_o : out std_ulogic := '0'
    );
end;

architecture arch of gddr6_axi_ctrl is
    -- We double buffer the address to allow for lookahead support
    signal next_address : address_t := IDLE_ADDRESS;
    signal address : address_t := IDLE_ADDRESS;

    signal byte_mask : std_ulogic_vector(127 downto 0) := (others => '0');
    signal byte_mask_valid : std_ulogic := '0';
    signal reserve_valid : std_ulogic := '0';


begin
    process (clk_i)
        -- Keep next_address populated when possible, maintain address_ready_o
        -- as the complement of next_address.valid for ping-pong handshake.
        procedure advance_next_address(next_ready : std_ulogic)
        is
            variable load_value : std_ulogic;
        begin
            advance_ping_pong_buffer(
                address_i.valid, next_ready,
                next_address.valid, address_ready_o,
                load_value);
            if load_value then
                next_address <= address_i;
            end if;
        end;

        -- Advances or loads the output address as appropriate, sets
        -- next_address_ready when we're ready to load a new address
        procedure advance_address(
            next_ready : std_ulogic;
            variable next_address_ready : out std_ulogic)
        is
            variable load_value : std_ulogic;
        begin
            advance_state_machine(
                next_address.valid, next_ready,
                address.count ?= 0, address.valid,
                next_address_ready, load_value);
            if load_value then
                if address.valid and address.count ?> 0 then
                    -- This assert checks against a harmless AXI protocol error,
                    -- not an error in the controller: address crosses 4K
                    -- boundary, but number of transfers is still correct
                    assert address.address(4 downto 0) /= 5X"1F"
                        report "Address increment crosses 4K boundary"
                        severity warning;
                    address <= (
                        address =>
                            -- The top 20 bits of the address are never
                            -- incremented as an AXI burst cannot cross a 4K
                            -- page boundary
                            address.address(24 downto 5) &
                            (address.address(4 downto 0) + 1),
                        count => address.count - 1,
                        valid => '1'
                    );
                else
                    address <= next_address;
                end if;
            end if;
        end;

        procedure advance_byte_mask(next_ready : std_ulogic)
        is
            variable load_value : std_ulogic;
        begin
            advance_ping_pong_buffer(
                byte_mask_valid_i, next_ready,
                byte_mask_valid, byte_mask_ready_o,
                load_value);
            if load_value then
                byte_mask <= byte_mask_i;
            end if;
        end;

        procedure advance_reserve(next_ready : std_ulogic)
        is
            variable load_value : std_ulogic;
        begin
            advance_ping_pong_buffer(
                reserve_valid_i, next_ready,
                reserve_valid, reserve_ready_o,
                load_value);
        end;

        procedure advance_ctrl(variable next_ctrl_ready : out std_ulogic)
        is
            variable next_valid : std_ulogic;
        begin
            next_valid := address.valid and byte_mask_valid and reserve_valid;
            if ctrl_ready_i or not ctrl_valid_o then
                ctrl_address_o <= address.address;
                ctrl_byte_mask_o <= byte_mask;
                ctrl_valid_o <= next_valid;
                next_ctrl_ready := next_valid;
            else
                next_ctrl_ready := '0';
            end if;
        end;


        variable next_ctrl_ready : std_ulogic;
        variable next_address_ready : std_ulogic;

    begin
        if rising_edge(clk_i) then
            advance_ctrl(next_ctrl_ready);
            advance_address(next_ctrl_ready, next_address_ready);
            advance_next_address(next_address_ready);
            advance_byte_mask(next_ctrl_ready);
            advance_reserve(next_ctrl_ready);
        end if;
    end process;

    lookahead_address_o <= next_address.address;
    lookahead_count_o <= address.count;
    lookahead_valid_o <= next_address.valid;
end;
