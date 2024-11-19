const std = @import("std");

// union size is right now 24 byte (16 for the union it self + 1 for enum + 7 for internal memory alignment)
// so it's basically the same as using pointers for storing 16 byte data types (big_int, array types)
// 16 (8 for pointers + 1 for enum + 7 for memory alignment) in the union, and 16 byte for the array type it self in the heap
// in total of (16 in the union + 16 in the heap) = 24 byte
// using pointers will only save memory in the case where it's small size data type like boolens
// and i will assume that the array types are the dominant types in the db

pub const PESP_Value_enum = enum(u8) {
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

pub const RESP_Value = union(PESP_Value_enum) {
    int: i64,
    big_int: i128,
    double: f64,
    bool: bool,
    string: []u8,
    simple_string: []u8,
    list: []RESP_Value,
    map: []RESP_Map,
    null: void,
    pub fn toStringAlloc(self: *const RESP_Value, allocator: std.mem.Allocator) ![]u8 {
        switch (self.*) {
            .int => |int| {
                return std.fmt.allocPrint(allocator, ":{}\r\n", .{int});
            },
            .big_int => |big_int| {
                return std.fmt.allocPrint(allocator, "({}\r\n", .{big_int});
            },
            .double => |double| {
                return std.fmt.allocPrint(allocator, ",{}\r\n", .{double});
            },
            .bool => |boolen| {
                return if (boolen) allocator.dupe(u8, "#t\r\n") else allocator.dupe(u8, "#t\r\n");
            },
            .string => |string| {
                return std.fmt.allocPrint(allocator, "${}\r\n{s}\r\n", .{ string.len, string });
            },
            .simple_string => |simple_string| {
                return std.fmt.allocPrint(allocator, "+{s}\r\n", .{simple_string});
            },
            .list => |list| {
                var output = try allocator.alloc(u8, 1024);
                errdefer allocator.free(output);
                var write_index: usize = 0;
                for (list) |value| {
                    const value_string = try value.toStringAlloc(allocator);
                    defer allocator.free(value_string);

                    if (value_string.len > output.len - write_index) {
                        output = try allocator.realloc(output, output.len + value_string.len);
                    }

                    std.mem.copyForwards(u8, output[write_index..output.len], value_string[0..value_string.len]);
                    write_index += value_string.len;
                }
                if (output.len > write_index) {
                    output = try allocator.realloc(output, write_index);
                }
                return output;
            },
            .map => |map| {
                var output = try allocator.alloc(u8, 1024);
                var write_index: usize = 0;
                errdefer allocator.free(output);

                for (map) |entry| {
                    // key
                    const key_str = try entry.key.toStringAlloc(allocator);
                    if (key_str.len > output.len - write_index) {
                        output = try allocator.realloc(output, output.len + 1024);
                    }
                    const key_str_in_output = try std.fmt.bufPrint(output[write_index..], "{s}", .{key_str});
                    write_index += key_str_in_output.len;

                    // value
                    const value_str = try entry.value.toStringAlloc(allocator);

                    if (value_str.len > output.len - write_index) {
                        output = try allocator.realloc(output, output.len + 1024);
                    }
                    const value_str_in_output = try std.fmt.bufPrint(output, "{s}", .{value_str});
                    write_index += value_str_in_output.len;
                }
                return output;
            },
            .null => return allocator.dupe(u8, "_\r\n"),
        }
        return allocator.dupe(u8, "");
    }

    pub fn fromToknizerAlloc(tokinizer: *tokenizerType, allocator: std.mem.Allocator) !*RESP_Value {
        const first_tokin = tokinizer.next().?;
        const value = try allocator.create(RESP_Value);

        const first_byte: PESP_Value_enum = @enumFromInt(first_tokin[0]);
        switch (first_byte) {
            PESP_Value_enum.int => {
                const int = try std.fmt.parseInt(i64, first_tokin[1..], 10);
                value.* = RESP_Value{ .int = int };
            },
            PESP_Value_enum.double => {
                const double = try std.fmt.parseFloat(f64, first_tokin[1..]);
                value.* = RESP_Value{ .double = double };
            },
            PESP_Value_enum.string => {
                const string = try allocator.dupe(u8, tokinizer.next().?);
                value.* = RESP_Value{ .string = string };
            },
            PESP_Value_enum.simple_string => {
                const string = try allocator.dupe(u8, first_tokin[1..]);
                value.* = RESP_Value{ .simple_string = string };
            },

            PESP_Value_enum.bool => {
                value.* = RESP_Value{ .bool = first_tokin[1] == 't' };
            },
            PESP_Value_enum.big_int => {
                const big_int = try std.fmt.parseInt(i128, first_tokin[1..], 10);
                value.* = RESP_Value{ .big_int = big_int };
            },
            PESP_Value_enum.list => {
                const list_len = try std.fmt.parseInt(usize, first_tokin[1..], 10);
                var list: []RESP_Value = try allocator.alloc(RESP_Value, list_len);
                for (0..list_len) |i| {
                    list[i] = (try fromToknizerAlloc(tokinizer, allocator)).*;
                }
                value.* = RESP_Value{ .list = list };
            },
            PESP_Value_enum.map => {
                const map_len = try std.fmt.parseInt(usize, first_tokin[1..], 10);
                var map: []RESP_Map = try allocator.alloc(RESP_Map, map_len);
                for (0..map_len) |i| {
                    map[i].key = (try fromToknizerAlloc(tokinizer, allocator)).*;
                    map[i].value = (try fromToknizerAlloc(tokinizer, allocator)).*;
                }
                value.* = RESP_Value{ .map = map };
            },
            PESP_Value_enum.null => {
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
