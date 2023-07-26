-- Decode registers into SYS and PHY groups

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.register_defs.all;
use work.register_defines.all;

entity decode_registers is
    port (
        clk_i : in std_ulogic;
        riu_clk_ok_i : in std_ulogic;
        riu_clk_i : in std_ulogic;

        -- Top level register interface
        write_strobe_i : in std_ulogic;
        write_address_i : in unsigned(13 downto 0);
        write_data_i : in reg_data_t;
        write_ack_o : out std_ulogic;
        read_strobe_i : in std_ulogic;
        read_address_i : in unsigned(13 downto 0);
        read_data_o : out reg_data_t;
        read_ack_o : out std_ulogic;

        -- SYS registers
        sys_write_strobe_o : out std_ulogic_vector(SYS_REGS_RANGE);
        sys_write_data_o : out reg_data_array_t(SYS_REGS_RANGE);
        sys_write_ack_i : in std_ulogic_vector(SYS_REGS_RANGE);
        sys_read_data_i : in reg_data_array_t(SYS_REGS_RANGE);
        sys_read_strobe_o : out std_ulogic_vector(SYS_REGS_RANGE);
        sys_read_ack_i : in std_ulogic_vector(SYS_REGS_RANGE);

        -- PHY registers on riu_clk_i
        phy_write_strobe_o : out std_ulogic_vector(PHY_REGS_RANGE);
        phy_write_data_o : out reg_data_array_t(PHY_REGS_RANGE);
        phy_write_ack_i : in std_ulogic_vector(PHY_REGS_RANGE);
        phy_read_data_i : in reg_data_array_t(PHY_REGS_RANGE);
        phy_read_strobe_o : out std_ulogic_vector(PHY_REGS_RANGE);
        phy_read_ack_i : in std_ulogic_vector(PHY_REGS_RANGE)
    );
end;

architecture arch of decode_registers is
    -- Decoding SYS/PHY mapping
    constant DECODE_BIT : natural := 5;
    subtype SYS_ADDRESS_RANGE is natural range DECODE_BIT-1 downto 0;
    subtype PHY_ADDRESS_RANGE is natural range DECODE_BIT-1 downto 0;

    -- Decoded sys
    signal sys_write_strobe : std_ulogic;
    signal sys_write_address : unsigned(SYS_ADDRESS_RANGE);
    signal sys_write_data : reg_data_t;
    signal sys_write_ack : std_ulogic;
    signal sys_read_strobe : std_ulogic;
    signal sys_read_address : unsigned(SYS_ADDRESS_RANGE);
    signal sys_read_data : reg_data_t;
    signal sys_read_ack : std_ulogic;

    -- Decoded phy
    signal phy_write_strobe : std_ulogic;
    signal phy_write_address : unsigned(PHY_ADDRESS_RANGE);
    signal phy_write_data : reg_data_t;
    signal phy_write_ack : std_ulogic;
    signal phy_read_strobe : std_ulogic;
    signal phy_read_address : unsigned(PHY_ADDRESS_RANGE);
    signal phy_read_data : reg_data_t;
    signal phy_read_ack : std_ulogic;

    -- From CC to strobe generator
    signal cc_phy_write_strobe : std_ulogic;
    signal cc_phy_write_address : unsigned(PHY_ADDRESS_RANGE);
    signal cc_phy_write_data : reg_data_t;
    signal cc_phy_write_ack : std_ulogic;
    signal cc_phy_read_strobe : std_ulogic;
    signal cc_phy_read_address : unsigned(PHY_ADDRESS_RANGE);
    signal cc_phy_read_data : reg_data_t;
    signal cc_phy_read_ack : std_ulogic;

begin
    -- Decode between SYS and PHY.  We should be able to do this combinatorialy,
    -- as the address remains valid between strobe and ack, and we don't care
    -- about other signals inbetween
    process (all) begin
        case write_address_i(DECODE_BIT) is
            when '0' =>
                sys_write_strobe <= write_strobe_i;
                phy_write_strobe <= '0';
                write_ack_o <= sys_write_ack;
            when '1' =>
                sys_write_strobe <= '0';
                phy_write_strobe <= write_strobe_i;
                write_ack_o <= phy_write_ack;
            when others =>
        end case;
        case read_address_i(DECODE_BIT) is
            when '0' =>
                sys_read_strobe <= read_strobe_i;
                phy_read_strobe <= '0';
                read_data_o <= sys_read_data;
                read_ack_o <= sys_read_ack;
            when '1' =>
                sys_read_strobe <= '0';
                phy_read_strobe <= read_strobe_i;
                read_data_o <= phy_read_data;
                read_ack_o <= phy_read_ack;
            when others =>
        end case;
    end process;
    sys_write_address <= write_address_i(SYS_ADDRESS_RANGE);
    sys_write_data <= write_data_i;
    phy_write_address <= write_address_i(PHY_ADDRESS_RANGE);
    phy_write_data <= write_data_i;
    sys_read_address <= read_address_i(SYS_ADDRESS_RANGE);
    phy_read_address <= read_address_i(PHY_ADDRESS_RANGE);


    -- SYS addresses to strobe array
    sys_register_mux : entity work.register_mux generic map (
        BUFFER_DEPTH => 1
    ) port map (
        clk_i => clk_i,

        write_strobe_i => sys_write_strobe,
        write_address_i => sys_write_address,
        write_data_i => sys_write_data,
        write_ack_o => sys_write_ack,
        read_strobe_i => sys_read_strobe,
        read_address_i => sys_read_address,
        read_data_o => sys_read_data,
        read_ack_o => sys_read_ack,

        write_strobe_o => sys_write_strobe_o,
        write_data_o => sys_write_data_o,
        write_ack_i => sys_write_ack_i,
        read_strobe_o => sys_read_strobe_o,
        read_data_i => sys_read_data_i,
        read_ack_i => sys_read_ack_i
    );


    -- Bring the PHY register interface over to CK clock
    bank_cc : entity work.register_bank_cc port map (
        clk_in_i => clk_i,
        clk_out_i => riu_clk_i,
        clk_out_ok_i => riu_clk_ok_i,

        write_address_i => phy_write_address,
        write_data_i => phy_write_data,
        write_strobe_i => phy_write_strobe,
        write_ack_o => phy_write_ack,
        read_address_i => phy_read_address,
        read_data_o => phy_read_data,
        read_strobe_i => phy_read_strobe,
        read_ack_o => phy_read_ack,

        write_address_o => cc_phy_write_address,
        write_data_o => cc_phy_write_data,
        write_strobe_o => cc_phy_write_strobe,
        write_ack_i => cc_phy_write_ack,
        read_address_o => cc_phy_read_address,
        read_data_i => cc_phy_read_data,
        read_strobe_o => cc_phy_read_strobe,
        read_ack_i => cc_phy_read_ack
    );


    -- PHY addresses to strobe array
    phy_register_mux : entity work.register_mux generic map (
        BUFFER_DEPTH => 1
    ) port map (
        clk_i => riu_clk_i,

        write_strobe_i => cc_phy_write_strobe,
        write_address_i => cc_phy_write_address,
        write_data_i => cc_phy_write_data,
        write_ack_o => cc_phy_write_ack,
        read_strobe_i => cc_phy_read_strobe,
        read_address_i => cc_phy_read_address,
        read_data_o => cc_phy_read_data,
        read_ack_o => cc_phy_read_ack,

        write_strobe_o => phy_write_strobe_o,
        write_data_o => phy_write_data_o,
        write_ack_i => phy_write_ack_i,
        read_strobe_o => phy_read_strobe_o,
        read_data_i => phy_read_data_i,
        read_ack_i => phy_read_ack_i
    );
end;
