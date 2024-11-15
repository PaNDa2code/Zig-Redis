const std = @import("std");

pub const ValueTypeEnum = enum {
    int,
    float,
    bool,
    string,
    list,
};

pub const Value = union(ValueTypeEnum) {
    int: i64,
    float: f64,
    bool: bool,
    string: *const []u8,
    list: *const []Value,
};

test "play ground" {
    const allocator = std.testing.allocator;

    var string = try allocator.alloc(u8, 10);
    defer allocator.free(string);

    std.mem.copyBackwards(u8, string, "HelloWorld");

    var list = try allocator.alloc(Value, 2);
    defer allocator.free(list);

    list[0] = Value{ .string = &string };

    const value = Value{ .list = &list };

    switch (value) {
        .int => {
            std.debug.print("it's int\n", .{});
        },
        .string => {
            std.debug.print("It's a string\n", .{});
        },
        .bool => {
            std.debug.print("It's a bool\n", .{});
        },
        .float => {
            std.debug.print("It's a float\n", .{});
        },
        .list => {
            std.debug.print("It's a list\n", .{});
        },
    }
}
