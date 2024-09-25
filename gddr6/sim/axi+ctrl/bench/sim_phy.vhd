-- Simulates PHY interface and SG memory

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

use work.gddr6_defs.all;
use work.gddr6_ctrl_timing_defs.all;
use work.gddr6_ctrl_delay_defs.all;
use work.gddr6_ctrl_command_defs.all;

use work.sim_phy_defs.all;

entity sim_phy is
    port (
        clk_i : in std_ulogic;

        ca_i : in phy_ca_t;
        dq_i : in phy_dq_out_t;
        dq_o : out phy_dq_in_t
    );
end;

architecture arch of sim_phy is
    -- Closing the loop for writes.  The transmitter _ctrl_data should be using
    -- the following delay calculation:
    --  CA_OUTPUT_DELAY + WLmrs - TX_OUTPUT_DELAY
    -- Our write processing actually takes place 4 ticks after we see

    -- Delay from RD/WxM command to corresponding read or write strobe from
    -- command interpreter.  Data is written on the strobe, updated on the tick
    -- after the strobe.
    constant READ_STROBE_DELAY : natural := 1;
    constant WRITE_STROBE_DELAY : natural := 4;
    constant READ_MEMORY_DELAY : natural := 1;

    -- Align read and write data with model
    constant READ_DELAY : natural :=
        RLmrs + RX_INPUT_DELAY - READ_STROBE_DELAY - READ_MEMORY_DELAY;
    -- edc_read is sent at the same time as received data
    constant READ_EDC_DELAY : natural := READ_DELAY;
    -- Delay EDC from read data to expected EDC in
    constant READ_EDC_IN_DELAY : natural :=
        RLmrs + CRCRL + EDC_INPUT_DELAY - READ_STROBE_DELAY - READ_MEMORY_DELAY;
    constant SELECT_READ_EDC_IN_DELAY : natural :=
        RLmrs + CRCRL + EDC_INPUT_DELAY - READ_STROBE_DELAY;

    constant WRITE_DELAY : natural :=
        WRITE_STROBE_DELAY - WLmrs + TX_OUTPUT_DELAY;
    -- Delay from dq_i.data
    constant WRITE_EDC_DELAY : natural := TX_EDC_DELAY;
    constant WRITE_EDC_IN_DELAY : natural :=
        TX_EDC_DELAY + CRCWL + EDC_INPUT_DELAY;
    -- Delay from write strobe to write_edc_in valid
    constant SELECT_WRITE_EDC_IN_DELAY : natural :=
        WLmrs + CRCWL + EDC_INPUT_DELAY - WRITE_STROBE_DELAY;


    signal read_address : sg_address_t;
    signal read_strobe : std_ulogic;
    signal read_data : phy_data_t;
    signal read_data_out : phy_data_t;
    signal read_edc : phy_edc_t;
    signal read_edc_out : phy_edc_t;
    signal read_edc_in : phy_edc_t;

    signal write_address : sg_address_t;
    signal write_mask : sg_write_mask_t;
    signal write_strobe : std_ulogic;
    signal write_data : phy_data_t;
    signal write_edc : phy_edc_t;
    signal write_edc_out : phy_edc_t;
    signal write_edc_in : phy_edc_t;

    -- EDC out selection, emulating SG EDC generation
    signal select_read_edc_in : std_ulogic := '0';
    signal select_write_edc_in : std_ulogic := '0';
    signal edc_in : phy_edc_t;


    -- The CA output from CTRL is one tick later than the reference above, we
    -- need to take this into account in the SG simulation here by delaying ca_i
    -- by one tick.  We might as well turn ca_phy_t back into ca_command_t at
    -- the same time.
    constant CA_DELAY_OFFSET : natural := 1;
    signal ca_in : ca_command_t;


    -- Helper functions for generating delays
    function to_std_ulogic_vector(value : vector_array) return std_ulogic_vector
    is
        constant ARRAY_LENGTH : natural := value'LENGTH;
        constant VECTOR_LENGTH : natural := value'ELEMENT'LENGTH;
        variable result :
            std_logic_vector(ARRAY_LENGTH*VECTOR_LENGTH-1 downto 0);
    begin
        for i in 0 to ARRAY_LENGTH-1 loop
            for j in 0 to VECTOR_LENGTH-1 loop
                result(i * VECTOR_LENGTH + j) := value(i)(j);
            end loop;
        end loop;
        return result;
    end;

    function to_vector_array(value : std_ulogic_vector) return vector_array
    is
        constant VECTOR_LENGTH : natural := 8;
        constant ARRAY_LENGTH : natural := value'LENGTH / VECTOR_LENGTH;
        variable result :
            vector_array(ARRAY_LENGTH-1 downto 0)(VECTOR_LENGTH-1 downto 0);
    begin
        for i in 0 to ARRAY_LENGTH-1 loop
            for j in 0 to VECTOR_LENGTH-1 loop
                result(i)(j) := value(i * VECTOR_LENGTH + j);
            end loop;
        end loop;
        return result;
    end;


begin
    -- Logs commands as they are received at the memory
    decode : entity work.decode_commands generic map (
        ASSERT_UNEXPECTED => true
    ) port map (
        clk_i => clk_i,
        ca_command_i => ca_in
    );


    -- Interpret SG commands
    command : entity work.sim_phy_command generic map (
        READ_STROBE_DELAY => READ_STROBE_DELAY,
        WRITE_STROBE_DELAY => WRITE_STROBE_DELAY
    ) port map (
        clk_i => clk_i,

        ca_i => ca_in,

        read_address_o => read_address,
        read_strobe_o => read_strobe,

        write_address_o => write_address,
        write_mask_o => write_mask,
        write_strobe_o => write_strobe
    );


    -- Manage memory
    memory : entity work.sim_phy_memory port map (
        clk_i => clk_i,

        read_address_i => read_address,
        read_strobe_i => read_strobe,
        read_data_o => read_data,

        write_address_i => write_address,
        write_mask_i => write_mask,
        write_strobe_i => write_strobe,
        write_data_i => write_data
    );


    -- EDC computation on read and write data
    write_edc_inst : entity work.gddr6_phy_crc port map (
        clk_i => clk_i,
        data_i => dq_i.data,
        dbi_n_i => (others => (others => '1')),
        edc_o => write_edc
    );

    read_edc_inst : entity work.gddr6_phy_crc port map (
        clk_i => clk_i,
        data_i => read_data,
        dbi_n_i => (others => (others => '1')),
        edc_o => read_edc
    );


    -- Delay CA to match delay at SG
    delay_ca_sg : entity work.fixed_delay generic map (
        DELAY => CA_OUTPUT_DELAY - CA_DELAY_OFFSET,
        WIDTH => 24,
        INITIAL => '1'
    ) port map (
        clk_i => clk_i,
        data_i(9 downto 0) => ca_i.ca(0),
        data_i(19 downto 10) => ca_i.ca(1),
        data_i(23 downto 20) => ca_i.ca3,
        data_o(9 downto 0) => ca_in.ca(0),
        data_o(19 downto 10) => ca_in.ca(1),
        data_o(23 downto 20) => ca_in.ca3
    );


    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- Write delay alignment

    -- Align write data for when we're ready to process it
    delay_write : entity work.fixed_delay generic map (
        WIDTH => 512,
        DELAY => WRITE_DELAY,
        INITIAL => 'U'
    ) port map (
        clk_i => clk_i,
        data_i => to_std_ulogic_vector(dq_i.data),
        to_vector_array(data_o) => write_data
    );

    -- Generate EDC in response to write and delay as required
    delay_write_edc_out : entity work.fixed_delay generic map (
        WIDTH => 64,
        -- Subtract one tick to allow for computation of write_edc
        DELAY => WRITE_EDC_DELAY - 1
    ) port map (
        clk_i => clk_i,
        data_i => to_std_ulogic_vector(write_edc),
        to_vector_array(data_o) => write_edc_out
    );

    delay_write_edc_in : entity work.fixed_delay generic map (
        WIDTH => 64,
        -- Subtract one tick to allow for computation of write_edc, one tick
        -- for output assignment
        DELAY => WRITE_EDC_IN_DELAY - 2
    ) port map (
        clk_i => clk_i,
        data_i => to_std_ulogic_vector(write_edc),
        to_vector_array(data_o) => write_edc_in
    );

    delay_write_edc_select : entity work.fixed_delay generic map (
        -- Allow one tick for output assignment
        DELAY => SELECT_WRITE_EDC_IN_DELAY - 1
    ) port map (
        clk_i => clk_i,
        data_i(0) => write_strobe,
        data_o(0) => select_write_edc_in
    );


    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- Read delay alignment

    -- Ensure read data arrives when expected by CTRL
    delay_read : entity work.fixed_delay generic map (
        WIDTH => 512,
        DELAY => READ_DELAY,
        INITIAL => 'U'
    ) port map (
        clk_i => clk_i,
        data_i => to_std_ulogic_vector(read_data),
        to_vector_array(data_o) => read_data_out
    );

    -- Generate EDC in response to read and delay as required
    delay_read_edc_out : entity work.fixed_delay generic map (
        WIDTH => 64,
        -- Subtract one tick to allow for computation of read_edc
        DELAY => READ_EDC_DELAY - 1
    ) port map (
        clk_i => clk_i,
        data_i => to_std_ulogic_vector(read_edc),
        to_vector_array(data_o) => read_edc_out
    );

    delay_read_edc_in : entity work.fixed_delay generic map (
        WIDTH => 64,
        -- Subtract one tick to allow for computation of read_edc, plus one more
        -- tick for output assignment
        DELAY => READ_EDC_IN_DELAY - 2
    ) port map (
        clk_i => clk_i,
        data_i => to_std_ulogic_vector(read_edc),
        to_vector_array(data_o) => read_edc_in
    );

    delay_read_edc_select : entity work.fixed_delay generic map (
        -- Allow one tick for output assignment
        DELAY => SELECT_READ_EDC_IN_DELAY - 1
    ) port map (
        clk_i => clk_i,
        data_i(0) => read_strobe,
        data_o(0) => select_read_edc_in
    );


    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- EDC alignment

    -- Select between read and write EDC as appropriate to emulate returned EDC
    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Gather the appropriate EDC output
            edc_in <= (others => X"AA");       -- Test pattern by default
            assert not select_read_edc_in or not select_write_edc_in
                report "Somehow have simultaneous R/W EDC"
                severity failure;
            if select_read_edc_in then
                edc_in <= read_edc_in;
            elsif select_write_edc_in then
                edc_in <= write_edc_in;
            end if;
        end if;
    end process;


    dq_o <= (
        data => read_data_out,
        edc_in => edc_in,
        edc_write => write_edc_out,
        edc_read => read_edc_out
    );
end;
