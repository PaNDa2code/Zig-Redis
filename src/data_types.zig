const std = @import("std");

// union size is right now 24 byte (16 for the union it self + 1 for enum + 7 for internal memory alignment)
// so it's basically the same as using pointers for storing 16 byte data types (big_int, array types)
// 16 (8 for pointers + 1 for enum + 7 for memory alignment) in the union, and 16 byte for the array type it self in the heap
// in total of (16 in the union + 16 in the heap) = 24 byte
// using pointers will only save memory in the case where it's small size data type like boolens
// and i will assume that the array types are the dominant types in the db

pub const RESP_Value_enum = enum(u8) {
    int = ':',
    big_int = '(',
    double = ',',
    bool = '#',
    string = '$',
    simple_string = '+',
    list = '*',
    map = '%',
    null = '_',
};

pub const RESP_Value = union(RESP_Value_enum) {
    int: i64,
    big_int: i128,
    double: f64,
    bool: bool,
    string: []u8,
    simple_string: []u8,
    list: []RESP_Value,
    map: []RESP_Map,
    null: void,

    // for std.fmt
    pub fn format(self: *const RESP_Value, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = options; // autofix
        _ = fmt; // autofix
        switch (self.*) {
            .int => |int| {
                try writer.print(":{d}\r\n", .{int});
            },
            .big_int => |big_int| {
                try writer.print("({d}\r\n", .{big_int});
            },
            .double => |double| {
                try writer.print(",{d}\r\n", .{double});
            },
            .bool => |boolen| {
                if (boolen)
                    try writer.writeAll("#t\r\n")
                else
                    try writer.writeAll("#f\r\n");
            },
            .string => |string| {
                try writer.print("${}\r\n{s}\r\n", .{ string.len, string });
            },
            .simple_string => |simple_string| {
                try writer.print("+{s}\r\n", .{simple_string});
            },
            .list => |list| {
                try writer.print("*{}\r\n", .{list.len});
                for (list) |value| {
                    try writer.print("{}", .{value});
                }
            },
            .map => |map| {
                try writer.print("%{}\r\n", .{map.len});
                for (map) |entry| {
                    try writer.print("{}{}", .{ entry.key, entry.value });
                }
            },
            .null => {
                try writer.writeAll("_\r\n");
            },
        }
    }

    pub fn parseFromTokinizerAlloc(tokinizer: *tokenizerType, allocator: std.mem.Allocator) !*RESP_Value {
        const first_tokin = tokinizer.next().?;
        const value = try allocator.create(RESP_Value);

        const first_byte: RESP_Value_enum = @enumFromInt(first_tokin[0]);
        switch (first_byte) {
            RESP_Value_enum.int => {
                const int = try std.fmt.parseInt(i64, first_tokin[1..], 10);
                value.* = RESP_Value{ .int = int };
            },
            RESP_Value_enum.double => {
                const double = try std.fmt.parseFloat(f64, first_tokin[1..]);
                value.* = RESP_Value{ .double = double };
            },
            RESP_Value_enum.string => {
                const string = try allocator.dupe(u8, tokinizer.next().?);
                value.* = RESP_Value{ .string = string };
            },
            RESP_Value_enum.simple_string => {
                const string = try allocator.dupe(u8, first_tokin[1..]);
                value.* = RESP_Value{ .simple_string = string };
            },

            RESP_Value_enum.bool => {
                value.* = RESP_Value{ .bool = first_tokin[1] == 't' };
            },
            RESP_Value_enum.big_int => {
                const big_int = try std.fmt.parseInt(i128, first_tokin[1..], 10);
                value.* = RESP_Value{ .big_int = big_int };
            },
            RESP_Value_enum.list => {
                const list_len = try std.fmt.parseInt(usize, first_tokin[1..], 10);
                var list: []RESP_Value = try allocator.alloc(RESP_Value, list_len);
                for (0..list_len) |i| {
                    list[i] = (try parseFromTokinizer(tokinizer, allocator)).*;
                }
                value.* = RESP_Value{ .list = list };
            },
            RESP_Value_enum.map => {
                const map_len = try std.fmt.parseInt(usize, first_tokin[1..], 10);
                var map: []RESP_Map = try allocator.alloc(RESP_Map, map_len);
                for (0..map_len) |i| {
                    map[i].key = (try parseFromTokinizer(tokinizer, allocator)).*;
                    map[i].value = (try parseFromTokinizer(tokinizer, allocator)).*;
                }
                value.* = RESP_Value{ .map = map };
            },
            RESP_Value_enum.null => {
                value.* = RESP_Value{ .null = undefined };
            },
        }
        return value;
    }
};

pub const RESP_Map = struct {
    key: RESP_Value,
    value: RESP_Value,
};

const tokenizerType = std.mem.TokenIterator(u8, std.mem.DelimiterType.any);
