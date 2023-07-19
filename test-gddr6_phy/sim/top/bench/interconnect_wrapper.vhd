library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

entity interconnect_wrapper is
  port (
    DSP_CLK : in STD_LOGIC;
    DSP_RESETN : in STD_LOGIC;
    FCLKA_clk_n : in STD_LOGIC_VECTOR ( 0 to 0 );
    FCLKA_clk_p : in STD_LOGIC_VECTOR ( 0 to 0 );
    M_DSP_REGS_araddr : out STD_LOGIC_VECTOR ( 16 downto 0 );
    M_DSP_REGS_arprot : out STD_LOGIC_VECTOR ( 2 downto 0 );
    M_DSP_REGS_arready : in STD_LOGIC;
    M_DSP_REGS_arvalid : out STD_LOGIC;
    M_DSP_REGS_awaddr : out STD_LOGIC_VECTOR ( 16 downto 0 );
    M_DSP_REGS_awprot : out STD_LOGIC_VECTOR ( 2 downto 0 );
    M_DSP_REGS_awready : in STD_LOGIC;
    M_DSP_REGS_awvalid : out STD_LOGIC;
    M_DSP_REGS_bready : out STD_LOGIC;
    M_DSP_REGS_bresp : in STD_LOGIC_VECTOR ( 1 downto 0 );
    M_DSP_REGS_bvalid : in STD_LOGIC;
    M_DSP_REGS_rdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    M_DSP_REGS_rready : out STD_LOGIC;
    M_DSP_REGS_rresp : in STD_LOGIC_VECTOR ( 1 downto 0 );
    M_DSP_REGS_rvalid : in STD_LOGIC;
    M_DSP_REGS_wdata : out STD_LOGIC_VECTOR ( 31 downto 0 );
    M_DSP_REGS_wready : in STD_LOGIC;
    M_DSP_REGS_wstrb : out STD_LOGIC_VECTOR ( 3 downto 0 );
    M_DSP_REGS_wvalid : out STD_LOGIC;
    nCOLDRST : in STD_LOGIC;
    pcie_7x_mgt_0_rxn : in STD_LOGIC_VECTOR ( 3 downto 0 );
    pcie_7x_mgt_0_rxp : in STD_LOGIC_VECTOR ( 3 downto 0 );
    pcie_7x_mgt_0_txn : out STD_LOGIC_VECTOR ( 3 downto 0 );
    pcie_7x_mgt_0_txp : out STD_LOGIC_VECTOR ( 3 downto 0 )
  );
end interconnect_wrapper;

architecture STRUCTURE of interconnect_wrapper is
begin
end;
