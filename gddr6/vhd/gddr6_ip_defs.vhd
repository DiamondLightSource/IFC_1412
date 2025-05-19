-- Definitions required specifically for IP interface.  Structures exposed
-- through the IP interface need to be declared and managed here.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package gddr6_ip_defs is
    -- Event bits recording various AXI events.  Each bit is strobed when the
    -- corresponding event occurs
    type axi_stats_t is record
        write_frame_error : std_ulogic;     -- Invalid write address request
        write_crc_error : std_ulogic;       -- Write CRC error reported
        write_last_error : std_ulogic;      -- Data burst framing error

        write_address : std_ulogic;         -- Write address accepted
        write_transfer : std_ulogic;        -- Write transfer completed
        write_data_beat : std_ulogic;       -- Single write data transfer

        read_frame_error : std_ulogic;      -- Invalid read address request
        read_crc_error : std_ulogic;        -- Read CRC error reported

        read_address : std_ulogic;          -- Read address accepted
        read_transfer : std_ulogic;         -- Read transfer completed
        read_data_beat : std_ulogic;        -- Single read data transfer
    end record;

    -- Conversion functions
    function to_axi_stats_t(stats : std_ulogic_vector) return axi_stats_t;
    function to_std_ulogic_vector(stats : axi_stats_t) return std_ulogic_vector;
end;

package body gddr6_ip_defs is
    function to_axi_stats_t(stats : std_ulogic_vector) return axi_stats_t is
    begin
        return (
            write_frame_error => stats(0),
            write_crc_error   => stats(1),
            write_last_error  => stats(2),
            write_address     => stats(3),
            write_transfer    => stats(4),
            write_data_beat   => stats(5),
            read_frame_error  => stats(6),
            read_crc_error    => stats(7),
            read_address      => stats(8),
            read_transfer     => stats(9),
            read_data_beat    => stats(10)
        );
    end;

    function to_std_ulogic_vector(stats : axi_stats_t)
        return std_ulogic_vector is
    begin
        return (
            0 => stats.write_frame_error,
            1 => stats.write_crc_error,
            2 => stats.write_last_error,
            3 => stats.write_address,
            4 => stats.write_transfer,
            5 => stats.write_data_beat,
            6 => stats.read_frame_error,
            7 => stats.read_crc_error,
            8 => stats.read_address,
            9 => stats.read_transfer,
            10 => stats.read_data_beat
        );
    end;
end;
