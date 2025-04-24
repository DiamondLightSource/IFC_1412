library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.support.all;
use work.register_defs.all;
use work.register_defines.all;


architecture arch of top is
    -- Clock and resets
    signal clk : std_ulogic;
    signal reset_n : std_ulogic;
    signal pci_reset_n : std_ulogic;

    -- LEDs.  Illuminate LED A when out of reset, toggle LED B
    signal led_counter : unsigned(25 downto 0) := (others => '0');
    signal led_a : std_ulogic := '1';   -- Green if low
    signal led_b : std_ulogic := '1';   -- Red if low

    -- Register interface
    signal DSP_REGS_araddr : std_logic_vector(16 downto 0);
    signal DSP_REGS_arprot : std_logic_vector(2 downto 0);
    signal DSP_REGS_arready : std_logic;
    signal DSP_REGS_arvalid : std_logic;
    signal DSP_REGS_awaddr : std_logic_vector(16 downto 0);
    signal DSP_REGS_awprot : std_logic_vector(2 downto 0);
    signal DSP_REGS_awready : std_logic;
    signal DSP_REGS_awvalid : std_logic;
    signal DSP_REGS_bready : std_logic;
    signal DSP_REGS_bresp : std_logic_vector(1 downto 0);
    signal DSP_REGS_bvalid : std_logic;
    signal DSP_REGS_rdata : std_logic_vector(31 downto 0);
    signal DSP_REGS_rready : std_logic;
    signal DSP_REGS_rresp : std_logic_vector(1 downto 0);
    signal DSP_REGS_rvalid : std_logic;
    signal DSP_REGS_wdata : std_logic_vector(31 downto 0);
    signal DSP_REGS_wready : std_logic;
    signal DSP_REGS_wstrb : std_logic_vector(3 downto 0);
    signal DSP_REGS_wvalid : std_logic;

    -- Internal register path from AXI conversion
    signal REGS_write_strobe : std_ulogic;
    signal REGS_write_address : unsigned(13 downto 0);
    signal REGS_write_data : std_ulogic_vector(31 downto 0);
    signal REGS_write_ack : std_ulogic;
    signal REGS_read_strobe : std_ulogic;
    signal REGS_read_address : unsigned(13 downto 0);
    signal REGS_read_data : std_ulogic_vector(31 downto 0);
    signal REGS_read_ack : std_ulogic;

    -- Decoded register wiring
    signal write_strobe : std_ulogic_vector(TOP_REGS_RANGE);
    signal write_data : reg_data_array_t(TOP_REGS_RANGE);
    signal write_ack : std_ulogic_vector(TOP_REGS_RANGE);
    signal read_strobe : std_ulogic_vector(TOP_REGS_RANGE);
    signal read_data : reg_data_array_t(TOP_REGS_RANGE);
    signal read_ack : std_ulogic_vector(TOP_REGS_RANGE);

begin
    clocking : entity work.system_clocking port map (
        sysclk100MHz_p => pad_SYSCLK100_P,
        sysclk100MHz_n => pad_SYSCLK100_N,

        clk_o => clk,
        reset_n_o => reset_n,
        pci_reset_n_o => pci_reset_n
    );


    interconnect : entity work.interconnect_wrapper port map (
        -- PCIe MGT interface
        nCOLDRST => not pci_reset_n,
        FCLKA_clk_p(0) => pad_MGT224_REFCLK_P,
        FCLKA_clk_n(0) => pad_MGT224_REFCLK_N,
        pcie_7x_mgt_0_rxn => pad_AMC_PCI_RX_N,
        pcie_7x_mgt_0_rxp => pad_AMC_PCI_RX_P,
        pcie_7x_mgt_0_txn => pad_AMC_PCI_TX_N,
        pcie_7x_mgt_0_txp => pad_AMC_PCI_TX_P,

        -- DSP Register interface
        DSP_CLK => clk,
        DSP_RESETN => reset_n,
        M_DSP_REGS_araddr => DSP_REGS_araddr,
        M_DSP_REGS_arprot => DSP_REGS_arprot,
        M_DSP_REGS_arready => DSP_REGS_arready,
        M_DSP_REGS_arvalid => DSP_REGS_arvalid,
        M_DSP_REGS_awaddr => DSP_REGS_awaddr,
        M_DSP_REGS_awprot => DSP_REGS_awprot,
        M_DSP_REGS_awready => DSP_REGS_awready,
        M_DSP_REGS_awvalid => DSP_REGS_awvalid,
        M_DSP_REGS_bready => DSP_REGS_bready,
        M_DSP_REGS_bresp => DSP_REGS_bresp,
        M_DSP_REGS_bvalid => DSP_REGS_bvalid,
        M_DSP_REGS_rdata => DSP_REGS_rdata,
        M_DSP_REGS_rready => DSP_REGS_rready,
        M_DSP_REGS_rresp => DSP_REGS_rresp,
        M_DSP_REGS_rvalid => DSP_REGS_rvalid,
        M_DSP_REGS_wdata => DSP_REGS_wdata,
        M_DSP_REGS_wready => DSP_REGS_wready,
        M_DSP_REGS_wstrb => DSP_REGS_wstrb,
        M_DSP_REGS_wvalid => DSP_REGS_wvalid
    );


    -- Register AXI slave interface
    axi_lite_slave : entity work.axi_lite_slave port map (
        clk_i => clk,
        rstn_i => reset_n,

        -- AXI-Lite read interface
        araddr_i => DSP_REGS_araddr(15 downto 0),
        arprot_i => DSP_REGS_arprot,
        arvalid_i => DSP_REGS_arvalid,
        arready_o => DSP_REGS_arready,
        rdata_o => DSP_REGS_rdata,
        rresp_o => DSP_REGS_rresp,
        rvalid_o => DSP_REGS_rvalid,
        rready_i => DSP_REGS_rready,

        -- AXI-Lite write interface
        awaddr_i => DSP_REGS_awaddr(15 downto 0),
        awprot_i => DSP_REGS_awprot,
        awvalid_i => DSP_REGS_awvalid,
        awready_o => DSP_REGS_awready,
        wdata_i => DSP_REGS_wdata,
        wstrb_i => DSP_REGS_wstrb,
        wvalid_i => DSP_REGS_wvalid,
        wready_o => DSP_REGS_wready,
        bready_i => DSP_REGS_bready,
        bresp_o => DSP_REGS_bresp,
        bvalid_o => DSP_REGS_bvalid,

        -- Internal read interface
        read_strobe_o => REGS_read_strobe,
        read_address_o => REGS_read_address,
        read_data_i => REGS_read_data,
        read_ack_i => REGS_read_ack,

        -- Internal write interface
        write_strobe_o => REGS_write_strobe,
        write_address_o => REGS_write_address,
        write_data_o => REGS_write_data,
        write_ack_i => REGS_write_ack
    );


    -- Decode register addresses
    register_mux : entity work.register_mux port map (
        clk_i => clk,

        -- From AXI slave
        write_strobe_i => REGS_write_strobe,
        write_address_i => REGS_write_address,
        write_data_i => REGS_write_data,
        write_ack_o => REGS_write_ack,
        read_strobe_i => REGS_read_strobe,
        read_address_i => REGS_read_address,
        read_data_o => REGS_read_data,
        read_ack_o => REGS_read_ack,

        -- Decoded registers
        write_strobe_o => write_strobe,
        write_data_o => write_data,
        write_ack_i => write_ack,
        read_strobe_o => read_strobe,
        read_data_i => read_data,
        read_ack_i => read_ack
    );


    qspi : entity work.qspi port map (
        clk_i => clk,

        write_strobe_i => write_strobe(TOP_QSPI_REGS),
        write_data_i => write_data(TOP_QSPI_REGS),
        write_ack_o => write_ack(TOP_QSPI_REGS),
        read_strobe_i => read_strobe(TOP_QSPI_REGS),
        read_data_o => read_data(TOP_QSPI_REGS),
        read_ack_o => read_ack(TOP_QSPI_REGS),

        pad_USER_SPI_CS_L_o => pad_USER_SPI_CS_L,
        pad_USER_SPI_SCK_o => pad_USER_SPI_SCK,
        pad_USER_SPI_D_io => pad_USER_SPI_D,
        pad_FPGA_CFG_FCS2_B_o => pad_FPGA_CFG_FCS2_B,
        pad_FPGA_CFG_D_io => pad_FPGA_CFG_D
    );



    -- LED clocking
    process (clk) begin
        if rising_edge(clk) then
            led_a <= not pci_reset_n;

            led_counter <= led_counter + 1;
            led_b <= led_counter(led_counter'LEFT);

            pad_FP_LED2A_K <= led_a;
            pad_FP_LED2B_K <= led_b;
        end if;
    end process;
end;
