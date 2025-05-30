-- Data handling for read and write commands

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_ctrl_defs.all;
use work.gddr6_ctrl_timing_defs.all;
use work.gddr6_ctrl_delay_defs.all;

entity gddr6_ctrl_data is
    port (
        clk_i : in std_ulogic;

        -- Data completion events
        request_completion_i : in request_completion_t;

        -- Output enable
        output_enable_o : out std_ulogic := '0';

        -- Data to and from PHY
        phy_data_i : in phy_data_t;
        phy_data_o : out phy_data_t;
        -- EDC data
        edc_in_i : in phy_edc_t;
        edc_read_i : in phy_edc_t;
        edc_write_i : in phy_edc_t;

        -- AXI connection
        -- RD
        axi_rd_data_o : out ctrl_data_t;
        axi_rd_valid_o : out std_ulogic := '0';
        axi_rd_ok_o : out std_ulogic;
        axi_rd_ok_valid_o : out std_ulogic := '0';
        -- WR
        axi_wd_data_i : in ctrl_data_t;
        axi_wd_advance_o : out std_ulogic;
        axi_wd_ready_o : out std_ulogic := '0';
        axi_wr_ok_o : out std_ulogic := '1';
        axi_wr_ok_valid_o : out std_ulogic := '0'
    );
end;

architecture arch of gddr6_ctrl_data is
    -- Output enable
    signal output_enable : std_ulogic;

    -- Read
    signal read_complete_in : std_ulogic;
    signal read_start : std_ulogic;
    signal read_delay : std_ulogic := '0';
    signal read_start_edc : std_ulogic;
    signal read_edc_in : phy_edc_t;
    signal read_edc_in_ok : std_ulogic;
    signal read_check_edc : std_ulogic := '0';

    -- Write
    -- Note that channel enables are needed to guard the EDC check as disabled
    -- channels won't generate a valid EDC signal.
    signal write_complete_in : std_ulogic;
    signal write_edc_in : phy_edc_t;
    -- Relevant request signals delayed align with EDC: write_start_edc should
    -- be valid one tick before edc_in_i and write_edc_in become valid
    signal write_start_edc_in : std_ulogic;
    signal write_advance_edc_in : std_ulogic;
    signal write_enables_in : std_ulogic_vector(0 to 3);
    -- Delayed write_enables valid synchronous with edc_in_i, write_edc_in
    signal write_enables : std_ulogic_vector(0 to 3);
    signal write_advance_edc : std_ulogic := '0';
    -- Delayed valid signals
    signal write_start_edc : std_ulogic;
    signal write_last_edc : std_ulogic;


    -- Flatten and restore functions for interfacing EDC values to delay lines
    function from_edc(edc : phy_edc_t) return std_ulogic_vector
    is
        variable result : std_ulogic_vector(63 downto 0);
    begin
        for i in 0 to 7 loop
            result(8*i + 7 downto 8*i) := edc(i);
        end loop;
        return result;
    end;

    function to_edc(edc : std_ulogic_vector(63 downto 0)) return phy_edc_t
    is
        variable result : phy_edc_t;
    begin
        for i in 0 to 7 loop
            result(i) := edc(8*i + 7 downto 8*i);
        end loop;
        return result;
    end;


    -- Compare two arrays of EDC codes by channel.  Only check channels which
    -- are set in the mask
    function compare_by_channel(
        mask : std_ulogic_vector;
        a : phy_edc_t; b : phy_edc_t) return std_ulogic is
    begin
        for ch in 0 to 3 loop
            if mask(ch) then
                if a(2*ch + 1 downto 2*ch) /= b(2*ch + 1 downto 2*ch) then
                    return '0';
                end if;
            end if;
        end loop;
        return '1';
    end;

begin
    -- Completion calculation
    read_complete_in <=
        to_std_ulogic(request_completion_i.direction = DIR_READ) and
        request_completion_i.valid;
    write_complete_in <=
        to_std_ulogic(request_completion_i.direction = DIR_WRITE) and
        request_completion_i.valid;


    -- Output enable generation

    delay_output_enable : entity work.fixed_delay generic map (
        -- The delay is adjusted by 2: one tick to start the output one tick
        -- before data is sent, and one tick for a register in stretch_pulse
        DELAY => OUTPUT_ENABLE_DELAY - 2
    ) port map (
        clk_i => clk_i,
        data_i(0) => write_complete_in,
        data_o(0) => output_enable
    );

    stretch_output_enable : entity work.stretch_pulse generic map (
        -- Subtract one to account for register
        DELAY => OUTPUT_ENABLE_STRETCH - 1,
        REGISTER_OUT => true
    ) port map (
        clk_i => clk_i,
        pulse_i => output_enable,
        pulse_o => output_enable_o
    );


    -- Read processing

    -- Delay from outgoing command to data ready
    delay_read_start_inst : entity work.fixed_delay generic map (
        DELAY => READ_START_DELAY - 1
    ) port map (
        clk_i => clk_i,
        data_i(0) => read_complete_in,
        data_o(0) => read_start
    );

    -- Delay EDC calculated from data read to align with EDC from memory
    delay_read_edc_inst : entity work.fixed_delay generic map (
        DELAY => READ_EDC_DELAY,
        WIDTH => 64
    ) port map (
        clk_i => clk_i,
        data_i => from_edc(edc_read_i),
        to_edc(data_o) => read_edc_in
    );

    delay_read_check_inst : entity work.fixed_delay generic map (
        DELAY => READ_CHECK_DELAY + 1
    ) port map (
        clk_i => clk_i,
        data_i(0) => read_complete_in,
        data_o(0) => read_start_edc
    );


    -- Write processing

    delay_write_start_inst : entity work.fixed_delay generic map (
        -- axi_wd_{ready,advance}_o need to be presented one tick earlier than
        -- axi_wd_data_i needs to be valid, see gddr6_axi_data_fifo for details.
        DELAY => WRITE_START_DELAY - 1,
        WIDTH => 2
    ) port map (
        clk_i => clk_i,
        data_i(0) => write_complete_in,
        data_i(1) => request_completion_i.advance,
        data_o(0) => axi_wd_ready_o,
        data_o(1) => axi_wd_advance_o
    );

    delay_write_edc_inst : entity work.fixed_delay generic map (
        DELAY => WRITE_EDC_DELAY,
        WIDTH => 64
    ) port map (
        clk_i => clk_i,
        data_i => from_edc(edc_write_i),
        to_edc(data_o) => write_edc_in
    );

    delay_write_check_inst : entity work.fixed_delay generic map (
        DELAY => WRITE_CHECK_DELAY - 1,
        WIDTH => 6
    ) port map (
        clk_i => clk_i,
        data_i(0) => write_complete_in,
        data_i(1) => request_completion_i.advance,
        data_i(5 downto 2) => request_completion_i.enables,
        data_o(0) => write_start_edc_in,
        data_o(1) => write_advance_edc_in,
        data_o(5 downto 2) => write_enables_in
    );


    -- Map between PHY and AXI data formats.  PHY data is organised by pin and
    -- WCK tick, AXI data is flattened but organised into channels.
    gen_channel : for ch in 0 to 3 generate
        gen_lane : for lane in 0 to 15 generate
            constant wire : natural := 16 * ch + lane;
        begin
            gen_beat : for beat in 0 to 7 generate
                constant bit : natural := 16 * beat + lane;
            begin
                axi_rd_data_o(ch)(bit) <= phy_data_i(wire)(beat);
                phy_data_o(wire)(beat) <= axi_wd_data_i(ch)(bit);
            end generate;
        end generate;
    end generate;


    process (clk_i)
        variable write_edc_ok : std_ulogic;
    begin
        if rising_edge(clk_i) then
            -- Read generation: two ticks of read from start
            read_delay <= read_start;
            axi_rd_valid_o <= read_start or read_delay;

            -- Read CRC check
            read_edc_in_ok <= to_std_ulogic(read_edc_in = edc_in_i);
            read_check_edc <= read_start_edc;
            if read_start_edc then
                axi_rd_ok_o <= read_edc_in_ok;
            else
                axi_rd_ok_o <= axi_rd_ok_o and read_edc_in_ok;
            end if;
            axi_rd_ok_valid_o <= read_check_edc;

            -- Write CRC check
            -- Capture write and advance state
            if write_start_edc_in then
                write_enables <= write_enables_in;
                write_advance_edc <= write_advance_edc_in;
            end if;
            -- Delayed EDC valid signals
            write_start_edc <= write_start_edc_in;
            write_last_edc <= write_start_edc;
            -- Error calculation
            write_edc_ok :=
                compare_by_channel(write_enables, write_edc_in, edc_in_i);
            if write_start_edc or write_last_edc then
                -- Valid EDC data, up date ok status as appropriate
                if axi_wr_ok_valid_o then
                    axi_wr_ok_o <= write_edc_ok;
                else
                    axi_wr_ok_o <= write_edc_ok and axi_wr_ok_o;
                end if;
            elsif axi_wr_ok_valid_o then
                axi_wr_ok_o <= '1';
            end if;
            -- Output valid on final test
            axi_wr_ok_valid_o <= write_last_edc and write_advance_edc;
        end if;
    end process;
end;
