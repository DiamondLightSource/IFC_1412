-- IO pin assignments
--
-- Only IO buffers and logical gathering, no logic.  The delay and bitslice
-- management is generated elsewhere.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.support.all;

entity gddr6_phy_io is
    port (
        -- --------------------------------------------------------------------
        -- GDDR pins
        pad_SG12_CK_P_i : in std_ulogic;
        pad_SG12_CK_N_i : in std_ulogic;
        pad_SG1_WCK_P_i : in std_ulogic;
        pad_SG1_WCK_N_i : in std_ulogic;
        pad_SG2_WCK_P_i : in std_ulogic;
        pad_SG2_WCK_N_i : in std_ulogic;
        pad_SG1_RESET_N_o : out std_ulogic;
        pad_SG2_RESET_N_o : out std_ulogic;
        pad_SG12_CKE_N_o : out std_ulogic;
        pad_SG12_CABI_N_o : out std_ulogic;
        pad_SG12_CAL_o : out std_ulogic_vector(2 downto 0);
        pad_SG1_CA3_A_o : out std_ulogic;
        pad_SG1_CA3_B_o : out std_ulogic;
        pad_SG2_CA3_A_o : out std_ulogic;
        pad_SG2_CA3_B_o : out std_ulogic;
        pad_SG12_CAU_o : out std_ulogic_vector(9 downto 4);
        pad_SG1_DQ_A_io : inout std_logic_vector(15 downto 0);
        pad_SG1_DQ_B_io : inout std_logic_vector(15 downto 0);
        pad_SG2_DQ_A_io : inout std_logic_vector(15 downto 0);
        pad_SG2_DQ_B_io : inout std_logic_vector(15 downto 0);
        pad_SG1_DBI_N_A_io : inout std_logic_vector(1 downto 0);
        pad_SG1_DBI_N_B_io : inout std_logic_vector(1 downto 0);
        pad_SG2_DBI_N_A_io : inout std_logic_vector(1 downto 0);
        pad_SG2_DBI_N_B_io : inout std_logic_vector(1 downto 0);
        pad_SG1_EDC_A_io : inout std_logic_vector(1 downto 0);
        pad_SG1_EDC_B_io : inout std_logic_vector(1 downto 0);
        pad_SG2_EDC_A_io : inout std_logic_vector(1 downto 0);
        pad_SG2_EDC_B_io : inout std_logic_vector(1 downto 0);

        -- --------------------------------------------------------------------
        -- Clocks and reset
        io_ck_o : out std_ulogic;
        io_wck_o : out std_ulogic_vector(0 to 1);       -- One per IO bank
        io_sg_resets_n_i : in std_ulogic_vector(0 to 1); -- One per IO bank

        -- CA pins
        io_ca_i : in std_ulogic_vector(9 downto 0);     -- ca_i(3) is ignored
        -- Four separate CA3 pins, ca3_i(0) drives SG1A ... ca3_i(3) SG2B
        io_ca3_i : in std_ulogic_vector(0 to 3);        -- 1A 1B 2A 2B
        io_cabi_n_i : in std_ulogic;
        io_cke_n_i : in std_ulogic;

        -- DQ pins organised by IO bank, connected as in table below:
        --      dq(15:0)  <=> SG1A,   dq(31:16) <=> SG1B
        --      dq(47:32) <=> SG2A,   dq(63:48) <=> SG2B
        -- _i is output to device, _o input from device, _t is tristate control
        io_dq_i : in std_ulogic_vector(63 downto 0);
        io_dq_o : out std_ulogic_vector(63 downto 0);
        io_dq_t_i : in std_ulogic_vector(63 downto 0);
        -- Bus inversion signal and control associated with dq bytes
        io_dbi_n_i : in std_ulogic_vector(7 downto 0);
        io_dbi_n_o : out std_ulogic_vector(7 downto 0);
        io_dbi_n_t_i : in std_ulogic_vector(7 downto 0);
        -- Error detection code, association as for dbi, and startup config
        io_edc_o : out std_ulogic_vector(7 downto 0);
        io_edc_i : in std_ulogic_vector(7 downto 0);
        io_edc_t_i : in std_ulogic_vector(7 downto 0)
    );
end;

architecture arch of gddr6_phy_io is
begin
    -- Clock inputs
    i_clocks : entity work.ibufds_array generic map (
        COUNT => 3,
        DIFF_TERM => false
    ) port map (
        p_i(0) => pad_SG12_CK_P_i,        -- CK
        p_i(1) => pad_SG1_WCK_P_i,        -- WCK 1
        p_i(2) => pad_SG2_WCK_P_i,        -- WCK 2
        n_i(0) => pad_SG12_CK_N_i,
        n_i(1) => pad_SG1_WCK_N_i,
        n_i(2) => pad_SG2_WCK_N_i,
        o_o(0) => io_ck_o,
        o_o(1) => io_wck_o(0),
        o_o(2) => io_wck_o(1)
    );

    -- Resets and miscellaneous CA pins
    i_misc : entity work.obuf_array generic map (
        COUNT => 4
    ) port map (
        i_i(0) => io_sg_resets_n_i(0),
        i_i(1) => io_sg_resets_n_i(1),
        i_i(2) => io_cke_n_i,
        i_i(3) => io_cabi_n_i,
        o_o(0) => pad_SG1_RESET_N_o,
        o_o(1) => pad_SG2_RESET_N_o,
        o_o(2) => pad_SG12_CKE_N_o,
        o_o(3) => pad_SG12_CABI_N_o
    );


    -- -------------------------------------------------------------------------
    -- CA

    -- Gather CAL and CAU into a single array to make handling more convenient
    -- downstream.  ca_i(3) is simply ignored.
    i_ca : entity work.obuf_array generic map (
        COUNT => 9
    ) port map (
        i_i(2 downto 0) => io_ca_i(2 downto 0),
        i_i(8 downto 3) => io_ca_i(9 downto 4),
        o_o(2 downto 0) => pad_SG12_CAL_o,
        o_o(8 downto 3) => pad_SG12_CAU_o
    );

    -- Special handling of CA3
    i_ca3 : entity work.obuf_array generic map (
        COUNT => 4
    ) port map (
        i_i => reverse(io_ca3_i),
        o_o(0) => pad_SG1_CA3_A_o,
        o_o(1) => pad_SG1_CA3_B_o,
        o_o(2) => pad_SG2_CA3_A_o,
        o_o(3) => pad_SG2_CA3_B_o
    );


    -- -------------------------------------------------------------------------
    -- DQ

    i_dq : entity work.iobuf_array generic map (
        COUNT => 64
    ) port map (
        i_i => io_dq_i,
        t_i => io_dq_t_i,
        o_o => io_dq_o,
        io_io(15 downto 0) => pad_SG1_DQ_A_io,
        io_io(31 downto 16) => pad_SG1_DQ_B_io,
        io_io(47 downto 32) => pad_SG2_DQ_A_io,
        io_io(63 downto 48) => pad_SG2_DQ_B_io
    );

    i_dbi : entity work.iobuf_array generic map (
        COUNT => 8
    ) port map (
        i_i => io_dbi_n_i,
        t_i => io_dbi_n_t_i,
        o_o => io_dbi_n_o,
        io_io(1 downto 0) => pad_SG1_DBI_N_A_io,
        io_io(3 downto 2) => pad_SG1_DBI_N_B_io,
        io_io(5 downto 4) => pad_SG2_DBI_N_A_io,
        io_io(7 downto 6) => pad_SG2_DBI_N_B_io
    );

    i_edc : entity work.iobuf_array generic map (
        COUNT => 8
    ) port map (
        i_i => io_edc_i,
        t_i => io_edc_t_i,
        o_o => io_edc_o,
        io_io(1 downto 0) => pad_SG1_EDC_A_io,
        io_io(3 downto 2) => pad_SG1_EDC_B_io,
        io_io(5 downto 4) => pad_SG2_EDC_A_io,
        io_io(7 downto 6) => pad_SG2_EDC_B_io
    );
end;
