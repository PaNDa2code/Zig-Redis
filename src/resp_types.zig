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
    map: RESP_Map,
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

    pub fn parseFromSliceAlloc(slice: []const u8, allocator: std.mem.Allocator) !RESP_Value {
        var tokinizer = std.mem.tokenizeAny(u8, slice, "\r\n");
        return parseFromTokinizerAlloc(&tokinizer, allocator);
    }

    pub fn parseFromTokinizerAlloc(tokinizer: *tokenizerType, allocator: std.mem.Allocator) !RESP_Value {
        const first_tokin = tokinizer.next().?;
        var value: RESP_Value = undefined;

        const first_byte: RESP_Value_enum = @enumFromInt(first_tokin[0]);
        switch (first_byte) {
            RESP_Value_enum.int => {
                const int = try std.fmt.parseInt(i64, first_tokin[1..], 10);
                value = RESP_Value{ .int = int };
            },
            RESP_Value_enum.big_int => {
                const big_int = try std.fmt.parseInt(i128, first_tokin[1..], 10);
                value = RESP_Value{ .big_int = big_int };
            },
            RESP_Value_enum.double => {
                const double = try std.fmt.parseFloat(f64, first_tokin[1..]);
                value = RESP_Value{ .double = double };
            },
            RESP_Value_enum.string => {
                const string = try allocator.dupe(u8, tokinizer.next().?);
                value = RESP_Value{ .string = string };
            },
            RESP_Value_enum.simple_string => {
                const string = try allocator.dupe(u8, first_tokin[1..]);
                value = RESP_Value{ .simple_string = string };
            },
            RESP_Value_enum.bool => {
                value = RESP_Value{ .bool = first_tokin[1] == 't' };
            },
            RESP_Value_enum.list => {
                const list_len = try std.fmt.parseInt(usize, first_tokin[1..], 10);
                var list: []RESP_Value = try allocator.alloc(RESP_Value, list_len);
                for (0..list_len) |i| {
                    list[i] = try parseFromTokinizerAlloc(tokinizer, allocator);
                }
                value = RESP_Value{ .list = list };
            },
            RESP_Value_enum.map => {
                const map_len = try std.fmt.parseInt(usize, first_tokin[1..], 10);
                var map: []RESP_Map_Entry = try allocator.alloc(RESP_Map_Entry, map_len);
                for (0..map_len) |i| {
                    const temp_key = try parseFromTokinizerAlloc(tokinizer, allocator);
                    const temp_value = try parseFromTokinizerAlloc(tokinizer, allocator);
                    map[i].key = temp_key;
                    map[i].value = temp_value;
                }
                value = RESP_Value{ .map = map };
            },
            RESP_Value_enum.null => {
                value = RESP_Value{ .null = undefined };
            },
        }
        return value;
    }

    pub fn clean_up(self: *const RESP_Value, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .int, .big_int, .double, .bool, .null => {},
            .string, .simple_string => |s| {
                allocator.free(s);
            },
            .list => |list| {
                for (list) |item| {
                    item.clean_up(allocator);
                }
                allocator.free(list);
            },
            .map => |map| {
                for (map) |entry| {
                    entry.value.clean_up(allocator);
                    entry.key.clean_up(allocator);
                }
                allocator.free(map);
            },
        }
    }

    pub fn copy(self: *const RESP_Value, allocator: std.mem.Allocator) !RESP_Value {
        var value: RESP_Value = undefined;
        switch (self.*) {
            .int => |int| {
                value = RESP_Value{ .int = int };
            },
            .big_int => |big_int| {
                value = RESP_Value{ .big_int = big_int };
            },
            .double => |double| {
                value = RESP_Value{ .double = double };
            },
            .bool => |boolen| {
                value = RESP_Value{ .bool = boolen };
            },
            .string => |string| {
                value = RESP_Value{ .string = try allocator.dupe(u8, string) };
            },
            .simple_string => |simple_string| {
                value = RESP_Value{ .string = try allocator.dupe(u8, simple_string) };
            },
            .list => |list| {
                value = RESP_Value{ .list = try allocator.alloc(RESP_Value, list.len) };
                for (0..list.len) |i| {
                    value.list[i] = try list[i].copy(allocator);
                }
            },
            .map => |map| {
                value = RESP_Value{ .map = try allocator.alloc(RESP_Map_Entry, map.len) };
                for (0..map.len) |i| {
                    value.map[i].key = try map[i].key.copy(allocator);
                    value.map[i].value = try map[i].value.copy(allocator);
                }
            },
            .null => {
                value = RESP_Value{ .null = undefined };
            },
        }
        return value;
    }
};

pub const RESP_Map_Entry = struct {
    key: RESP_Value,
    value: RESP_Value,
};

pub const RESP_Map = []RESP_Map_Entry;

const tokenizerType = std.mem.TokenIterator(u8, std.mem.DelimiterType.any);
