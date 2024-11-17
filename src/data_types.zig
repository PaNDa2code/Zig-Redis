const std = @import("std");

// union size is right now 24 byte (16 for the union it self + 1 for enum + 7 for internal memory alignment)
// so it's basically the same as using pointers for storing 16 byte data types (big_int, array types)
// 16 (8 for pointers + 1 for enum + 7 for memory alignment) in the union, and 16 byte for the array type it self in the heap
// in total of (16 in the union + 16 in the heap) = 24 byte
// using pointers will only save memory in the case where it's small size data type like boolens
// and i will assume that the array types are the dominant types in the db

pub const PESP_Value = union(enum) {
    int: i64,
    big_int: i128,
    double: f64,
    bool: bool,
    string: []u8,
    list: []PESP_Value,
    map: []PESP_Map,
    null: void,

    pub fn to_string(self: *const PESP_Value, allocator: std.mem.Allocator) ![]u8 {
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
            .list => |list| {
                var output = try allocator.alloc(u8, 1024);
                errdefer allocator.free(output);
                var write_index: usize = 0;
                for (list) |value| {
                    const value_string = try value.to_string(allocator);
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
            .map => unreachable,
            .null => return allocator.dupe(u8, "_\r\n"),
        }
        return allocator.dupe(u8, "");
    }
};

pub const PESP_Map = struct {
    key: []u8,
    value: PESP_Value,
};
