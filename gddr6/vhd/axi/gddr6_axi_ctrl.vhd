-- Read/Write interface to CTRL

-- Converts SG address request into outgoing CTRL requests after ensuring that
-- the appropriate FIFO entries are reserved.  Byte mask support and response
-- reservation is not required for reads.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_axi_defs.all;

entity gddr6_axi_ctrl is
    port (
        clk_i : in std_ulogic;

        -- SG burst transfer request
        address_i : in address_t;
        address_ready_o : out std_ulogic := '1';

        -- The byte mask is available when data is available for writes, and
        -- can simply be ignored for reads
        byte_mask_i : in std_ulogic_vector(127 downto 0) := (others => '0');
        byte_mask_valid_i : in std_ulogic := '1';
        byte_mask_ready_o : out std_ulogic := '0';

        -- A FIFO result slot must be reserved before issuing a request
        reserve_o : out std_ulogic := '0';
        reserve_ready_i : in std_ulogic;

        -- Request to CTRL
        ctrl_address_o : out unsigned(24 downto 0);
        ctrl_byte_mask_o : out std_ulogic_vector(127 downto 0);
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

begin
    vars :
    process (clk_i)
        -- Advances or loads the output address as appropriate, sets
        -- address_ready when we're ready to load a new address
        procedure advance_address(
            variable next_address_ready : out std_ulogic) is
        begin
            if address.valid and address.count ?> 0 then
                assert address.count ?> 0 and address.valid severity failure;
                -- This assert indicates a harmless AXI protocol error, not an
                -- error in the controller
                assert address.address(4 downto 0) /= 5X"1F" severity warning;
                address <= (
                    address =>
                        -- The top 20 bits of the address are never incremented
                        -- as an AXI burst cannot cross a 4K page boundary
                        address.address(24 downto 5) &
                        (address.address(4 downto 0) + 1),
                    count => address.count - 1,
                    valid => '1'
                );
                next_address_ready := '0';
            else
                address <= next_address;
                next_address_ready := '1';
            end if;
        end;


        -- Keep next_address populated when possible, maintain address_ready_o
        -- as the complement of next_address.valid for ping-pong handshake.
        procedure advance_next_address(next_address_ready : std_ulogic) is
        begin
            if next_address_ready and next_address.valid then
                next_address.valid <= '0';
                address_ready_o <= '1';
            elsif address_i.valid and not next_address.valid then
                next_address <= address_i;
                address_ready_o <= '0';
            end if;
        end;

        variable next_address_valid : std_ulogic;
        variable next_ctrl_ready : std_ulogic;
        variable next_ctrl_valid : std_ulogic;
        variable next_address_ready : std_ulogic;

    begin
        if rising_edge(clk_i) then
            -- Whether a valid new address is available
            next_address_valid :=
                next_address.valid or (address.valid and address.count ?> 0);
            next_ctrl_ready := not ctrl_valid_o or ctrl_ready_i;

            next_ctrl_valid :=
                next_ctrl_ready and
                next_address_valid and byte_mask_valid_i and reserve_ready_i;



            -- Advance the output
            if next_ctrl_ready then
                ctrl_byte_mask_o <= byte_mask_i;
                ctrl_valid_o <= next_ctrl_valid;
            end if;

            -- Advance the address when loading
            if next_ctrl_valid then
                advance_address(next_address_ready);
            else
                next_address_ready := '0';
            end if;

            advance_next_address(next_address_ready);

            byte_mask_ready_o <=
                next_ctrl_valid and
                byte_mask_valid_i and not byte_mask_ready_o;
            if next_ctrl_valid and byte_mask_valid_i then
                ctrl_byte_mask_o <= byte_mask_i;
            end if;
            reserve_o <=
                next_ctrl_valid and
                reserve_ready_i and not reserve_o;
        end if;
    end process;

    ctrl_address_o <= address.address;
    lookahead_address_o <= next_address.address;
    lookahead_count_o <= address.count;
    lookahead_valid_o <= next_address.valid;
end;
