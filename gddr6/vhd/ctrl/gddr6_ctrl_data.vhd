-- Data handling for read and write commands

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.gddr6_ctrl_core_defs.all;
use work.gddr6_ctrl_timing_defs.all;

entity gddr6_ctrl_data is
    port (
        clk_i : in std_ulogic;

        -- Data completion events
        request_completion_i : in request_completion_t;

        -- Output enable
        write_active_i : in std_ulogic;
        output_enable_o : out std_ulogic;

        -- Data to and from PHY
        phy_data_i : in vector_array(63 downto 0)(7 downto 0);
        phy_data_o : out vector_array(63 downto 0)(7 downto 0);
        -- EDC data
        edc_in_i : in vector_array(7 downto 0)(7 downto 0);
        edc_read_i : in vector_array(7 downto 0)(7 downto 0);
        edc_write_i : in vector_array(7 downto 0)(7 downto 0);

        -- AXI connection
        -- RD
        axi_rd_data_o : out vector_array(0 to 3)(127 downto 0);
        axi_rd_valid_o : out std_ulogic;
        axi_rd_ok_o : out std_ulogic;
        axi_rd_ok_valid_o : out std_ulogic;
        -- WR
        axi_wd_data_i : in vector_array(0 to 3)(127 downto 0);
        axi_wd_advance_o : out std_ulogic;
        axi_wd_ready_o : out std_ulogic;
        axi_wr_ok_o : out std_ulogic;
        axi_wr_ok_valid_o : out std_ulogic
    );
end;

architecture arch of gddr6_ctrl_data is
    -- DQ output enable is asserted when writing data, and we allow one tick
    -- margin either side.
    constant DELAY_WRITE_ACTIVE : natural := WLmrs;
    constant DELAY_WRITE_ACTIVE_EXTRA : natural := 2;

    -- This delay takes account of the extra delay from sending a command to
    -- seeing the response; this needs to be added to incoming data and EDC.
    constant DELAY_LOOP : natural := 5;

    -- Delays for read
    constant DELAY_READ_START : natural := RLmrs + DELAY_LOOP - 1;
    constant DELAY_READ_CHECK : natural := CRCRL + 1;
    -- read_edc_i arrives one tick after data_i, edc_in_i CRCRL ticks after, but
    -- one tick ahead of data_i, so in fact this delay is zero!
    constant DELAY_READ_EDC : natural := CRCRL - 2;

    -- Delays for write
    constant DELAY_WRITE_START : natural := WLmrs;
    constant DELAY_WRITE_CHECK : natural := CRCWL + 1 + DELAY_LOOP;
    constant DELAY_WRITE_EDC : natural := CRCWL - 2;

    -- Output enable
    signal write_active_in : std_ulogic;
    signal write_active_delay : std_ulogic;

    -- Read
    signal read_complete_in : std_ulogic;
    signal read_start : std_ulogic;
    signal read_delay : std_ulogic := '0';
    signal read_start_edc : std_ulogic;
    signal read_edc_in : vector_array(7 downto 0)(7 downto 0);
    signal read_edc_in_ok : std_ulogic;
    signal read_check_edc : std_ulogic := '0';

    -- Write
    -- A couple of complications relative to read: first, we need to transmit
    -- the write_advance signal at the same time as data ready, and second, the
    -- channel enables need to guard the EDC check as disabled channels won't
    -- generate a valid EDC signal.
    signal write_complete_in : std_ulogic;
    signal write_start : std_ulogic;
    signal write_delay : std_ulogic := '0';
    signal write_advance : std_ulogic;
    signal write_enables_in : std_ulogic_vector(0 to 3);
    signal write_enables : std_ulogic_vector(0 to 3);
    signal write_edc_in : vector_array(7 downto 0)(7 downto 0);
    signal write_edc_ok : std_ulogic_vector(0 to 3);
    signal write_last_edc_ok : std_ulogic_vector(0 to 3);
    signal write_start_edc : std_ulogic;
    signal write_check_edc : std_ulogic := '0';
    signal write_check_valid_out : std_ulogic := '0';



    function from_edc(edc : vector_array) return std_ulogic_vector
    is
        variable result : std_ulogic_vector(63 downto 0);
    begin
        for i in 0 to 7 loop
            result(8*i + 7 downto 8*i) := edc(i);
        end loop;
        return result;
    end;

    function to_edc(edc : std_ulogic_vector(63 downto 0)) return vector_array
    is
        variable result : vector_array(7 downto 0)(7 downto 0);
    begin
        for i in 0 to 7 loop
            result(i) := edc(8*i + 7 downto 8*i);
        end loop;
        return result;
    end;

    -- Compare two arrays of EDC codes by channel
    function compare_by_channel(a : vector_array; b : vector_array)
        return std_ulogic_vector
    is
        variable result : std_ulogic_vector(0 to 3);
    begin
        for ch in 0 to 3 loop
            result(ch) := to_std_ulogic(
                a(2*ch + 1 downto 2*ch) = b(2*ch + 1 downto 2*ch));
        end loop;
        return result;
    end;

begin
    -- Output enable generation
    delay_write_active_inst : entity work.fixed_delay generic map (
        DELAY => DELAY_WRITE_ACTIVE
    ) port map (
        clk_i => clk_i,
        data_i(0) => write_active_i,
        data_o(0) => write_active_in
    );

    delay_write_active_extra_inst : entity work.fixed_delay generic map (
        DELAY => DELAY_WRITE_ACTIVE_EXTRA
    ) port map (
        clk_i => clk_i,
        data_i(0) => write_active_in,
        data_o(0) => write_active_delay
    );


    -- Read processing

    -- Delay from outgoing command to data ready
    read_complete_in <=
        to_std_ulogic(request_completion_i.direction = DIR_READ) and
        request_completion_i.valid;
    delay_read_start_inst : entity work.fixed_delay generic map (
        DELAY => DELAY_READ_START
    ) port map (
        clk_i => clk_i,
        data_i(0) => read_complete_in,
        data_o(0) => read_start
    );

    -- Delay from data arriving to EDC
    delay_read_check_inst : entity work.fixed_delay generic map (
        DELAY => DELAY_READ_CHECK
    ) port map (
        clk_i => clk_i,
        data_i(0) => read_start,
        data_o(0) => read_start_edc
    );

    -- Delay EDC calculated from data read to align with EDC from memory
    delay_read_edc_inst : entity work.fixed_delay generic map (
        DELAY => DELAY_READ_EDC,
        WIDTH => 64
    ) port map (
        clk_i => clk_i,
        data_i => from_edc(edc_read_i),
        to_edc(data_o) => read_edc_in
    );


    -- Write processing
    write_complete_in <=
        to_std_ulogic(request_completion_i.direction = DIR_WRITE) and
        request_completion_i.valid;
    delay_write_start_inst : entity work.fixed_delay generic map (
        DELAY => DELAY_WRITE_START,
        WIDTH => 2
    ) port map (
        clk_i => clk_i,
        data_i(0) => write_complete_in,
        data_i(1) => request_completion_i.advance,
        data_o(0) => write_start,
        data_o(1) => write_advance
    );

    delay_write_check_inst : entity work.fixed_delay generic map (
        DELAY => DELAY_WRITE_CHECK,
        WIDTH => 5
    ) port map (
        clk_i => clk_i,
        data_i(0) => write_complete_in,
        data_i(4 downto 1) => request_completion_i.enables,
        data_o(0) => write_start_edc,
        data_o(4 downto 1) => write_enables_in
    );

    delay_write_edc_inst : entity work.fixed_delay generic map (
        DELAY => DELAY_WRITE_EDC,
        WIDTH => 64
    ) port map (
        clk_i => clk_i,
        data_i => from_edc(edc_write_i),
        to_edc(data_o) => write_edc_in
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


    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Output enable generation, slightly stretched from write_active
            output_enable_o <= write_active_in or write_active_delay;

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


            -- Write generation: two ticks of write from start
            write_delay <= write_start;
            if write_start then
                axi_wd_advance_o <= write_advance;
            end if;
            axi_wd_ready_o <= write_start or write_delay;

            -- Write CRC check
            write_edc_ok <= compare_by_channel(write_edc_in, edc_in_i);
            write_last_edc_ok <= write_edc_ok;
            if write_start_edc then
                write_enables <= write_enables_in;
            end if;
            axi_wr_ok_o <= vector_and(
                not write_enables or (write_last_edc_ok and write_edc_ok));
            write_check_edc <= write_start_edc;
            write_check_valid_out <= write_check_edc;
            axi_wr_ok_valid_o <= write_check_valid_out;
        end if;
    end process;
end;
