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
    signal user_clk : std_ulogic := '0';
    signal fpga_clk : std_ulogic := '0';

    signal user_spi_cs_n : std_ulogic := '1';
    signal fpga1_spi_cs_n : std_ulogic := '1';
    signal fpga2_spi_cs_n : std_ulogic := '1';
    signal user_mosi : std_ulogic := '1';
    signal fpga1_mosi : std_ulogic := '1';
    signal fpga2_mosi : std_ulogic := '1';
    signal user_miso : std_ulogic := '1';
    signal fpga1_miso : std_ulogic := '1';
    signal fpga2_miso : std_ulogic := '1';

    signal startup_di : std_ulogic_vector(3 downto 0);

    -- Here is an unexpected unpleasantness: according to UG570, "The first
    -- three clock cycles on USRCCLKO ... will not be output on the external
    -- CCLK pin.  So we run a tiny startup engine to sort this out.
    constant STARTUP_DELAY : natural := 10;
    signal startup_counter : natural range 0 to STARTUP_DELAY := STARTUP_DELAY;

    -- Place all SPI IO registers on the IO block where possible.  The SEL_FPGA1
    -- registers have to go through STARTUPE3 so we exclude them here.
    attribute IOB : string;
    attribute IOB of user_clk : signal is "TRUE";
    attribute IOB of fpga2_spi_cs_n : signal is "TRUE";
    attribute IOB of user_spi_cs_n : signal is "TRUE";
    attribute IOB of fpga2_mosi : signal is "TRUE";
    attribute IOB of user_mosi : signal is "TRUE";
    attribute IOB of fpga2_miso : signal is "TRUE";
    attribute IOB of user_miso : signal is "TRUE";

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
        DO => (0 => fpga1_mosi, others => '1'),
        DTS => ( 0 => '0', 1 => '1', others => '0' ),
        FCSBO => fpga1_spi_cs_n,
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
    pad_FPGA_CFG_FCS2_B_o <= fpga2_spi_cs_n;
    pad_FPGA_CFG_D_io <= ( 4 => fpga2_mosi, 5 => 'Z', others => '1' );

    -- USER signals
    pad_USER_SPI_CS_L_o <= user_spi_cs_n;
    pad_USER_SPI_SCK_o <= user_clk;
    pad_USER_SPI_D_io <= ( 0 => user_mosi, 1 => 'Z', others => '1' );


    -- Register outgoing and incoming signals.  These delays will need to be
    -- taken into account when receiving SPI data
    process (clk_i)
        variable fpga_clk_out : std_ulogic;
    begin
        if rising_edge(clk_i) then
            -- Registered MISO inputs
            user_miso <= pad_USER_SPI_D_io(1);
            fpga1_miso <= startup_di(1);
            fpga2_miso <= pad_FPGA_CFG_D_io(5);

            -- Default output values
            user_clk <= '0';
            fpga_clk_out := '0';
            user_spi_cs_n <= '1';
            fpga1_spi_cs_n <= '1';
            fpga2_spi_cs_n <= '1';
            user_mosi <= '1';
            fpga1_mosi <= '1';
            fpga2_mosi <= '1';

            case select_i is
                when "00" =>
                    -- Nothing active
                when "01" =>
                    -- User FLASH
                    user_clk <= spi_clk_i;
                    user_spi_cs_n <= spi_cs_n_i;
                    user_mosi <= mosi_i;
                    miso_o <= user_miso;
                when "10" =>
                    -- FPGA1 config via STARTUPE3
                    fpga_clk_out := spi_clk_i;
                    fpga1_spi_cs_n <= spi_cs_n_i;
                    fpga1_mosi <= mosi_i;
                    miso_o <= fpga1_miso;
                when "11" =>
                    -- FPGA2 config
                    fpga_clk_out := spi_clk_i;
                    fpga2_spi_cs_n <= spi_cs_n_i;
                    fpga2_mosi <= mosi_i;
                    miso_o <= fpga2_miso;
                when others =>
            end case;

            -- Run USRCCLKO for a few cycles on startup
            if startup_counter > 0 then
                fpga_clk <= not fpga_clk;
                startup_counter <= startup_counter - 1;
            else
                fpga_clk <= fpga_clk_out;
            end if;
        end if;
    end process;
end;
