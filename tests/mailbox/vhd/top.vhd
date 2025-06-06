library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.register_defs.all;
use work.register_defines.all;

architecture arch of top is
    signal sysclk_in : std_ulogic;
    signal clk : std_ulogic;

    signal reset_counter : unsigned(10 downto 0) := (others => '1');
    signal reset_active : std_ulogic := '1';
    -- We need a separate PCIe Reset signal which is marked as asynchronous
    signal perst : std_ulogic := '1';
    attribute KEEP : string;
    attribute KEEP of perst : signal is "true";

    -- Wiring from AXI-Lite master to register slave
    signal DSP_REGS_araddr : std_ulogic_vector(16 downto 0);     -- AR
    signal DSP_REGS_arprot : std_ulogic_vector(2 downto 0);
    signal DSP_REGS_arready : std_ulogic;
    signal DSP_REGS_arvalid : std_ulogic;
    signal DSP_REGS_rdata : std_ulogic_vector(31 downto 0);      -- R
    signal DSP_REGS_rresp : std_ulogic_vector(1 downto 0);
    signal DSP_REGS_rready : std_ulogic;
    signal DSP_REGS_rvalid : std_ulogic;
    signal DSP_REGS_awaddr : std_ulogic_vector(16 downto 0);     -- AW
    signal DSP_REGS_awprot : std_ulogic_vector(2 downto 0);
    signal DSP_REGS_awready : std_ulogic;
    signal DSP_REGS_awvalid : std_ulogic;
    signal DSP_REGS_wdata : std_ulogic_vector(31 downto 0);      -- W
    signal DSP_REGS_wstrb : std_ulogic_vector(3 downto 0);
    signal DSP_REGS_wready : std_ulogic;
    signal DSP_REGS_wvalid : std_ulogic;
    signal DSP_REGS_bresp : std_ulogic_vector(1 downto 0);
    signal DSP_REGS_bready : std_ulogic;                         -- B
    signal DSP_REGS_bvalid : std_ulogic;

    -- System register wiring
    signal system_write_strobe : std_ulogic_vector(TOP_REGS_RANGE);
    signal system_write_data : reg_data_array_t(TOP_REGS_RANGE);
    signal system_write_ack : std_ulogic_vector(TOP_REGS_RANGE);
    signal system_read_strobe : std_ulogic_vector(TOP_REGS_RANGE);
    signal system_read_data : reg_data_array_t(TOP_REGS_RANGE);
    signal system_read_ack : std_ulogic_vector(TOP_REGS_RANGE);

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
    signal top_write_strobe : std_ulogic_vector(TOP_REGS_RANGE);
    signal top_write_data : reg_data_array_t(TOP_REGS_RANGE);
    signal top_write_ack : std_ulogic_vector(TOP_REGS_RANGE);
    signal top_read_strobe : std_ulogic_vector(TOP_REGS_RANGE);
    signal top_read_data : reg_data_array_t(TOP_REGS_RANGE);
    signal top_read_ack : std_ulogic_vector(TOP_REGS_RANGE);

begin
    -- Core clocking from copy of 100 MHz FCLKA
    sysclk_ibuf : IBUFDS port map (
        I => pad_SYSCLK100_P,
        IB => pad_SYSCLK100_N,
        O => sysclk_in
    );

    clk_bufg : BUFG port map (
        I => sysclk_in,
        O => clk
    );


    -- -------------------------------------------------------------------------
    -- Interconnect
    interconnect : entity work.interconnect_wrapper port map (
        -- Clocking and reset
        nCOLDRST => not perst,

        -- PCIe MGT interface
        FCLKA_clk_p(0) => pad_MGT224_REFCLK_P,
        FCLKA_clk_n(0) => pad_MGT224_REFCLK_N,
        pcie_7x_mgt_0_rxn => pad_AMC_PCI_RX_N,
        pcie_7x_mgt_0_rxp => pad_AMC_PCI_RX_P,
        pcie_7x_mgt_0_txn => pad_AMC_PCI_TX_N,
        pcie_7x_mgt_0_txp => pad_AMC_PCI_TX_P,

        -- Register clock and AXI reset
        DSP_CLK => clk,
        DSP_RESETN => not reset_active,

        -- AXI-Lite register master interface
        M_DSP_REGS_araddr => DSP_REGS_araddr,
        M_DSP_REGS_arprot => DSP_REGS_arprot,
        M_DSP_REGS_arready => DSP_REGS_arready,
        M_DSP_REGS_arvalid => DSP_REGS_arvalid,
        M_DSP_REGS_rdata => DSP_REGS_rdata,
        M_DSP_REGS_rresp => DSP_REGS_rresp,
        M_DSP_REGS_rready => DSP_REGS_rready,
        M_DSP_REGS_rvalid => DSP_REGS_rvalid,
        M_DSP_REGS_awaddr => DSP_REGS_awaddr,
        M_DSP_REGS_awprot => DSP_REGS_awprot,
        M_DSP_REGS_awready => DSP_REGS_awready,
        M_DSP_REGS_awvalid => DSP_REGS_awvalid,
        M_DSP_REGS_wdata => DSP_REGS_wdata,
        M_DSP_REGS_wstrb => DSP_REGS_wstrb,
        M_DSP_REGS_wready => DSP_REGS_wready,
        M_DSP_REGS_wvalid => DSP_REGS_wvalid,
        M_DSP_REGS_bresp => DSP_REGS_bresp,
        M_DSP_REGS_bready => DSP_REGS_bready,
        M_DSP_REGS_bvalid => DSP_REGS_bvalid
    );


    -- -------------------------------------------------------------------------
    -- AXI interfacing

    -- Register AXI slave interface
    axi_lite_slave : entity work.axi_lite_slave port map (
        clk_i => clk,
        rstn_i => not reset_active,

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
    register_mux : entity work.register_mux generic map (
        BUFFER_DEPTH => 1
    ) port map (
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
        write_strobe_o => top_write_strobe,
        write_data_o => top_write_data,
        write_ack_i => top_write_ack,
        read_strobe_o => top_read_strobe,
        read_data_i => top_read_data,
        read_ack_i => top_read_ack
    );


    -- Mailbox
    mailbox : entity work.mailbox port map (
        clk_i => clk,

        write_strobe_i => top_write_strobe(TOP_MAILBOX_REG),
        write_data_i => top_write_data(TOP_MAILBOX_REG),
        write_ack_o => top_write_ack(TOP_MAILBOX_REG),
        read_strobe_i => top_read_strobe(TOP_MAILBOX_REG),
        read_data_o => top_read_data(TOP_MAILBOX_REG),
        read_ack_o => top_read_ack(TOP_MAILBOX_REG),

        scl_i => pad_FPGA_SLAVE_SCL,
        sda_io => pad_FPGA_SLAVE_SDA
    );


    -- Create reset
    process (clk) begin
        if rising_edge(clk) then
            if reset_active then
                if reset_counter > 0 then
                    reset_counter <= reset_counter - 1;
                else
                    reset_active <= '0';
                    perst <= '0';
                end if;
            end if;
        end if;
    end process;
end;
