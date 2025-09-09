library ieee;
use ieee.std_logic_1164.all;

entity interconnect_wrapper is
    port (
        nCOLDRST : in std_logic;
        FCLKA_clk_n : in std_logic_vector(0 to 0);
        FCLKA_clk_p : in std_logic_vector(0 to 0);
        pcie_7x_mgt_0_rxn : in std_logic_vector(3 downto 0);
        pcie_7x_mgt_0_rxp : in std_logic_vector(3 downto 0);
        pcie_7x_mgt_0_txn : out std_logic_vector(3 downto 0);
        pcie_7x_mgt_0_txp : out std_logic_vector(3 downto 0);

        DSP_CLK : in std_logic;
        DSP_RESETN : in std_logic;
        M_DSP_REGS_araddr : out std_logic_vector(16 downto 0);
        M_DSP_REGS_arprot : out std_logic_vector(2 downto 0);
        M_DSP_REGS_arready : in std_logic;
        M_DSP_REGS_arvalid : out std_logic;
        M_DSP_REGS_awaddr : out std_logic_vector(16 downto 0);
        M_DSP_REGS_awprot : out std_logic_vector(2 downto 0);
        M_DSP_REGS_awready : in std_logic;
        M_DSP_REGS_awvalid : out std_logic;
        M_DSP_REGS_bready : out std_logic;
        M_DSP_REGS_bresp : in std_logic_vector(1 downto 0);
        M_DSP_REGS_bvalid : in std_logic;
        M_DSP_REGS_rdata : in std_logic_vector(31 downto 0);
        M_DSP_REGS_rready : out std_logic;
        M_DSP_REGS_rresp : in std_logic_vector(1 downto 0);
        M_DSP_REGS_rvalid : in std_logic;
        M_DSP_REGS_wdata : out std_logic_vector(31 downto 0);
        M_DSP_REGS_wready : in std_logic;
        M_DSP_REGS_wstrb : out std_logic_vector(3 downto 0);
        M_DSP_REGS_wvalid : out std_logic
    );
end;

architecture arch of interconnect_wrapper is
begin
    M_DSP_REGS_araddr <= (others => 'X');
    M_DSP_REGS_arprot <= (others => 'X');
    M_DSP_REGS_arvalid <= '0';
    M_DSP_REGS_awaddr <= (others => 'X');
    M_DSP_REGS_awprot <= (others => 'X');
    M_DSP_REGS_awvalid <= '0';
    M_DSP_REGS_bready <= '0';
    M_DSP_REGS_rready <= '0';
    M_DSP_REGS_wdata <= (others => 'X');
    M_DSP_REGS_wstrb <= (others => 'X');
    M_DSP_REGS_wvalid <= '0';
end;
