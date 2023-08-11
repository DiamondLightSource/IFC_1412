-- PHY interface for one BITSLICE nibble
--
-- Note that in this application the 7th bit is never used: bit N12 of each byte
-- is assigned to a non-bitslice application; therefore we simply ignore it.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.support.all;

entity gddr6_phy_nibble is
    generic (
        -- Selects which bitslices to instantiate
        BITSLICE_WANTED : std_ulogic_vector(0 to 5);
        REFCLK_FREQUENCY : real;
        -- Initial delay, used for calibration
        INITIAL_DELAY : natural;

        -- The upper nibble always receives clocks from the lower nibble
        LOWER_NIBBLE : boolean;
        -- For the lower nibble, the clock either comes from bitslice 0 or from
        -- another byte, and clocks are distributed to adjacent bytes
        CLK_FROM_PIN : boolean;         -- Set if clock from bitslice 0
        CLK_TO_NORTH : boolean;         -- Set if clock to north enabled
        CLK_TO_SOUTH : boolean          -- Set if clock to south enabled
    );

    port (
        -- Clocks
        pll_clk_i : in std_ulogic;      -- Backbone clock from PLL
        fifo_rd_clk_i : in std_ulogic;  -- Clock for reading RX FIFO

        -- FIFO control (maybe want to handle inside, or as part of reset)
        fifo_empty_o : out std_ulogic_vector(0 to 5);
        fifo_rd_en_i : in std_ulogic;

        -- Resets and controls
        reset_i : in std_ulogic;
        enable_control_vtc_i : in std_ulogic;
        enable_tri_vtc_i : in std_ulogic;
        enable_bitslice_vtc_i : in std_ulogic_vector(0 to 5);
        dly_ready_o : out std_ulogic;
        vtc_ready_o : out std_ulogic;

        -- RIU interface
        riu_clk_i : in std_ulogic;      -- Control clock
        riu_addr_i : in unsigned(5 downto 0);
        riu_wr_data_i : in std_ulogic_vector(15 downto 0);
        riu_rd_data_o : out std_ulogic_vector(15 downto 0);
        riu_valid_o : out std_ulogic;
        riu_wr_en_i : in std_ulogic;
        riu_nibble_sel_i : in std_ulogic;

        -- Data interface
        data_o : out vector_array(0 to 5)(7 downto 0);
        data_i : in vector_array(0 to 5)(7 downto 0);
        tbyte_i : in std_ulogic_vector(3 downto 0);

        pad_in_i : in std_ulogic_vector(0 to 5);
        pad_out_o : out std_ulogic_vector(0 to 5);
        pad_t_out_o : out std_ulogic_vector(0 to 5);

        -- Inter-byte clocking
        clk_from_ext_i : in std_ulogic;
        clk_to_north_o : out std_ulogic;
        clk_to_south_o : out std_ulogic;
        -- Inter-nibble clocking
        pclk_nibble_i : in std_ulogic;
        nclk_nibble_i : in std_ulogic;
        pclk_nibble_o : out std_ulogic;
        nclk_nibble_o : out std_ulogic
    );
end;

architecture arch of gddr6_phy_nibble is
    -- Plumbing between BITSLICE_CONTROL and {RXTX,TRI}_BITSLICE
    signal rx_bit_ctrl_in : vector_array(0 to 5)(39 downto 0);
    signal tx_bit_ctrl_in : vector_array(0 to 5)(39 downto 0);
    signal rx_bit_ctrl_out : vector_array(0 to 5)(39 downto 0);
    signal tx_bit_ctrl_out : vector_array(0 to 5)(39 downto 0);
    signal tx_bit_ctrl_in_tri : std_ulogic_vector(39 downto 0);
    signal tx_bit_ctrl_out_tri : std_ulogic_vector(39 downto 0);

    signal tri_out_to_tbyte : std_ulogic;

    function choose(choice : boolean; if_true : string; if_false : string)
        return string is
    begin
        if choice then
            return if_true;
        else
            return if_false;
        end if;
    end function;

begin
    control : BITSLICE_CONTROL generic map (
        DIV_MODE => "DIV4",                 -- 1:8 division in bitslice
        REFCLK_SRC => "PLLCLK",
        SELF_CALIBRATE => "ENABLE",
        -- Clock distribution
        EN_OTHER_PCLK => choose(LOWER_NIBBLE, "FALSE", "TRUE"),
        EN_OTHER_NCLK => choose(LOWER_NIBBLE, "FALSE", "TRUE"),
        EN_CLK_TO_EXT_NORTH => choose(CLK_TO_NORTH, "ENABLE", "DISABLE"),
        EN_CLK_TO_EXT_SOUTH => choose(CLK_TO_SOUTH, "ENABLE", "DISABLE")
    ) port map (
        DLY_RDY => dly_ready_o,
        DYN_DCI => open,
        VTC_RDY => vtc_ready_o,
        EN_VTC => enable_control_vtc_i,

        PLL_CLK => pll_clk_i,
        REFCLK => '0',
        RST => reset_i,
        TBYTE_IN => tbyte_i,

        -- Register interface unit
        RIU_CLK => riu_clk_i,
        RIU_ADDR => std_ulogic_vector(riu_addr_i),
        RIU_VALID => riu_valid_o,
        RIU_RD_DATA => riu_rd_data_o,
        RIU_WR_DATA => riu_wr_data_i,
        RIU_WR_EN => riu_wr_en_i,
        RIU_NIBBLE_SEL => riu_nibble_sel_i,

        -- RX clock distribution
        CLK_TO_EXT_NORTH => clk_to_north_o,
        CLK_TO_EXT_SOUTH => clk_to_south_o,
        CLK_FROM_EXT => clk_from_ext_i,
        PCLK_NIBBLE_OUT => pclk_nibble_o,
        NCLK_NIBBLE_OUT => nclk_nibble_o,
        PCLK_NIBBLE_IN => pclk_nibble_i,
        NCLK_NIBBLE_IN => nclk_nibble_i,

        -- No special PHY control
        PHY_RDCS0 => "0000",
        PHY_RDCS1 => "0000",
        PHY_RDEN => "1111",
        PHY_WRCS0 => "0000",
        PHY_WRCS1 => "0000",

        -- Control interface to bitslices
        RX_BIT_CTRL_IN0 => rx_bit_ctrl_in(0),
        RX_BIT_CTRL_IN1 => rx_bit_ctrl_in(1),
        RX_BIT_CTRL_IN2 => rx_bit_ctrl_in(2),
        RX_BIT_CTRL_IN3 => rx_bit_ctrl_in(3),
        RX_BIT_CTRL_IN4 => rx_bit_ctrl_in(4),
        RX_BIT_CTRL_IN5 => rx_bit_ctrl_in(5),
        RX_BIT_CTRL_IN6 => (others => '0'),
        TX_BIT_CTRL_IN0 => tx_bit_ctrl_in(0),
        TX_BIT_CTRL_IN1 => tx_bit_ctrl_in(1),
        TX_BIT_CTRL_IN2 => tx_bit_ctrl_in(2),
        TX_BIT_CTRL_IN3 => tx_bit_ctrl_in(3),
        TX_BIT_CTRL_IN4 => tx_bit_ctrl_in(4),
        TX_BIT_CTRL_IN5 => tx_bit_ctrl_in(5),
        TX_BIT_CTRL_IN6 => (others => '0'),
        RX_BIT_CTRL_OUT0 => rx_bit_ctrl_out(0),
        RX_BIT_CTRL_OUT1 => rx_bit_ctrl_out(1),
        RX_BIT_CTRL_OUT2 => rx_bit_ctrl_out(2),
        RX_BIT_CTRL_OUT3 => rx_bit_ctrl_out(3),
        RX_BIT_CTRL_OUT4 => rx_bit_ctrl_out(4),
        RX_BIT_CTRL_OUT5 => rx_bit_ctrl_out(5),
        RX_BIT_CTRL_OUT6 => open,
        TX_BIT_CTRL_OUT0 => tx_bit_ctrl_out(0),
        TX_BIT_CTRL_OUT1 => tx_bit_ctrl_out(1),
        TX_BIT_CTRL_OUT2 => tx_bit_ctrl_out(2),
        TX_BIT_CTRL_OUT3 => tx_bit_ctrl_out(3),
        TX_BIT_CTRL_OUT4 => tx_bit_ctrl_out(4),
        TX_BIT_CTRL_OUT5 => tx_bit_ctrl_out(5),
        TX_BIT_CTRL_OUT6 => open,
        TX_BIT_CTRL_IN_TRI => tx_bit_ctrl_in_tri,
        TX_BIT_CTRL_OUT_TRI => tx_bit_ctrl_out_tri
    );


    bitslice_tri : TX_BITSLICE_TRI generic map (
        DATA_WIDTH => 8,
        DELAY_FORMAT => "TIME",
        DELAY_TYPE => "FIXED",
        DELAY_VALUE => INITIAL_DELAY,
        REFCLK_FREQUENCY => REFCLK_FREQUENCY
    ) port map (
        TRI_OUT => tri_out_to_tbyte,
        EN_VTC => enable_tri_vtc_i,
        RST => reset_i,
        RST_DLY => reset_i,
        -- Control interface
        BIT_CTRL_IN => tx_bit_ctrl_out_tri,
        BIT_CTRL_OUT => tx_bit_ctrl_in_tri,
        -- Delay
        CLK => '0',
        CE => '0',
        INC => '0',
        LOAD => '0',
        CNTVALUEIN => 9X"000",
        CNTVALUEOUT => open
    );


    gen_bits : for i in 0 to 5 generate
        function rx_data_type return string is
        begin
            if BITSLICE_WANTED(i) then
                if i = 0 and CLK_FROM_PIN then
                    -- Incoming clock
                    return "DATA_AND_CLOCK";
                else
                    -- Normal data slice
                    return "DATA";
                end if;
            else
                -- Nothing in this position
                return "UNUSED";
            end if;
        end;

    begin
        gen_bitslice : if rx_data_type /= "UNUSED" generate
            bitslice : RXTX_BITSLICE generic map (
                RX_DATA_TYPE => rx_data_type,
                RX_DATA_WIDTH => 8,
                TX_DATA_WIDTH => 8,
                RX_DELAY_FORMAT => "TIME",
                TX_DELAY_FORMAT => "TIME",
                RX_DELAY_TYPE => "VAR_LOAD",
                TX_DELAY_TYPE => "VAR_LOAD",
                RX_DELAY_VALUE => INITIAL_DELAY,
                TX_DELAY_VALUE => INITIAL_DELAY,
                RX_REFCLK_FREQUENCY => REFCLK_FREQUENCY,
                TX_REFCLK_FREQUENCY => REFCLK_FREQUENCY,
                ENABLE_PRE_EMPHASIS => "TRUE",
                TBYTE_CTL => "TBYTE_IN"
            ) port map (
                -- Receiver
                DATAIN => pad_in_i(i),          -- Data in from pad
                FIFO_EMPTY => fifo_empty_o(i),  -- Read FIFO empty
                FIFO_RD_CLK => fifo_rd_clk_i,   -- Clock to read fifo
                FIFO_RD_EN => fifo_rd_en_i,     -- FIFO enable
                Q => data_o(i),                 -- Data in read

                FIFO_WRCLK_OUT => open,

                -- Transmitter
                D => data_i(i),
                O => pad_out_o(i),

                T_OUT => pad_t_out_o(i),        -- Tristate control out to pad
                T => '0',
                TBYTE_IN => tri_out_to_tbyte,

                RX_EN_VTC => enable_bitslice_vtc_i(i),
                TX_EN_VTC => enable_bitslice_vtc_i(i),
                RX_RST => reset_i,
                RX_RST_DLY => reset_i,
                TX_RST => reset_i,
                TX_RST_DLY => reset_i,

                -- Control interface
                RX_BIT_CTRL_OUT => rx_bit_ctrl_in(i),
                RX_BIT_CTRL_IN => rx_bit_ctrl_out(i),
                TX_BIT_CTRL_OUT => tx_bit_ctrl_in(i),
                TX_BIT_CTRL_IN => tx_bit_ctrl_out(i),

                -- Delay management interface
                RX_CLK => '0',
                RX_CE => '0',
                RX_INC => '0',
                RX_LOAD => '0',
                RX_CNTVALUEIN => 9X"000",
                RX_CNTVALUEOUT => open,
                TX_CLK => '0',
                TX_CE => '0',
                TX_INC => '0',
                TX_LOAD => '0',
                TX_CNTVALUEIN => 9X"000",
                TX_CNTVALUEOUT => open
            );

        else generate
            -- Fill in unconnected signals
            fifo_empty_o(i) <= '0';
            rx_bit_ctrl_in(i) <= (others => '0');
            tx_bit_ctrl_in(i) <= (others => '0');
            -- Simulation needs the following unused values to be assigned,
            -- otherwise a storm of error messages is generated.
            data_o(i) <= 8X"00";
            pad_out_o(i) <= '0';
            pad_t_out_o(i) <= '0';
        end generate;
    end generate;
end;
