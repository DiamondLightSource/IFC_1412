-- Mapping of QSPI pins to IO including tristate control

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity flash_io is
    port (
        clk_i : in std_ulogic;

        -- IO pins
        pad_USER_SPI_CS_L_o : out std_ulogic;
        pad_USER_SPI_SCK_o : out std_ulogic;
        pad_USER_SPI_D_io : inout std_logic_vector(3 downto 0);
        pad_FPGA_CFG_FCS2_B_o : out std_ulogic;
        pad_FPGA_CFG_D_io : inout std_logic_vector(7 downto 4);

        -- Selects which interface to use:
        --  0   => No target
        --  1   => User config
        --  2   => FPGA1
        --  3   => FPGA2
        select_i : in std_ulogic_vector(1 downto 0);
        spi_clk_i : in std_ulogic;
        spi_cs_n_i : in std_ulogic;
        mosi_i : in std_logic;
        miso_o : out std_ulogic := '1'
    );
end;

architecture arch of flash_io is
    type spi_target_t is (SEL_USER, SEL_FPGA1, SEL_FPGA2);
    type spi_bits_t is array(spi_target_t) of std_ulogic;

    signal fpga_clk : std_ulogic := '0';
    signal user_clk : std_ulogic := '0';
    signal mosi : spi_bits_t := (others => '1');
    signal miso : spi_bits_t;
    signal spi_cs_n : spi_bits_t := (others => '1');

    signal startup_di : std_ulogic_vector(3 downto 0);

    -- Here is an unexpected unpleasantness: according to UG570, "The first
    -- three clock cycles on USRCCLKO ... will not be output on the external
    -- CCLK pin.  So we run a tiny startup engine to sort this out.
    constant STARTUP_DELAY : natural := 10;
    signal startup_counter : natural range 0 to STARTUP_DELAY := STARTUP_DELAY;

begin
    -- For all QSPI signals the assignments are as follows:
    --  IO0: SI data from master to slave
    --  IO1: SO data from slave to master
    --  IO2: WP# write protect, unconditionally held high to enable writes
    --  IO3: HOLD# unconditionally held high
    -- Note that both IO2 and IO3 are internally pulled up and so could instead
    -- be left floating

    -- All the signals for FPGA CONFIG 1 have to be routed through the STARTUPE3
    -- component
    startup : STARTUPE3 port map (
        CFGCLK => open,
        CFGMCLK => open,
        EOS => open,
        PREQ => open,
        DI => startup_di,
        DO => (0 => mosi(SEL_FPGA1), others => '1'),
        DTS => ( 0 => '0', 1 => '1', others => '0' ),
        FCSBO => spi_cs_n(SEL_FPGA1),
        FCSBTS => '0',
        GSR => '0',
        GTS => '0',
        KEYCLEARB => '1',
        PACK => '0',
        USRCCLKO => fpga_clk,
        USRCCLKTS => '0',
        USRDONEO => '1',
        USRDONETS => '0'
    );

    -- FPGA CONFIG 2 signals
    pad_FPGA_CFG_FCS2_B_o <= spi_cs_n(SEL_FPGA2);
    pad_FPGA_CFG_D_io <= ( 4 => mosi(SEL_FPGA2), 5 => 'Z', others => '1' );

    -- USER signals
    pad_USER_SPI_CS_L_o <= spi_cs_n(SEL_USER);
    pad_USER_SPI_SCK_o <= user_clk;
    pad_USER_SPI_D_io <= ( 0 => mosi(SEL_USER), 1 => 'Z', others => '1' );


    -- Register outgoing and incoming signals.  These delays will need to be
    -- taken into account when receiving SPI data
    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Run USRCCLKO for a few cycles on startup
            if startup_counter > 0 then
                fpga_clk <= not fpga_clk;
                startup_counter <= startup_counter - 1;
            else
                fpga_clk <= spi_clk_i;
            end if;

            user_clk <= spi_clk_i;

            miso(SEL_FPGA1) <= startup_di(1);
            miso(SEL_FPGA2) <= pad_FPGA_CFG_D_io(5);
            miso(SEL_USER) <= pad_USER_SPI_D_io(1);

            case select_i is
                when "00" =>
                    miso_o <= '1';
                    mosi <= (others => '1');
                    spi_cs_n <= (others => '1');
                when "01" =>
                    miso_o <= miso(SEL_USER);
                    mosi <= (SEL_USER => mosi_i, others => '1');
                    spi_cs_n <= (SEL_USER => spi_cs_n_i, others => '1');
                when "10" =>
                    miso_o <= miso(SEL_FPGA1);
                    mosi <= (SEL_FPGA1 => mosi_i, others => '1');
                    spi_cs_n <= (SEL_FPGA1 => spi_cs_n_i, others => '1');
                when "11" =>
                    miso_o <= miso(SEL_FPGA2);
                    mosi <= (SEL_FPGA2 => mosi_i, others => '1');
                    spi_cs_n <= (SEL_FPGA2 => spi_cs_n_i, others => '1');
                when others =>
            end case;
        end if;
    end process;
end;
