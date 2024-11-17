const std = @import("std");
const data_types = @import("../data_types.zig");
const PESP_Value = data_types.PESP_Value;
const PESP_Map = data_types.PESP_Map;

test "test_data_types" {
    const allocator = std.testing.allocator;

    // Create a string (heap-allocated)
    const string = try allocator.dupe(u8, "HelloWorld");
    defer allocator.free(string);

    // Create a PESP_Value with the string
    const value = PESP_Value{ .string = string };

    // Allocate memory for a list of PESP_Value
    var list = try allocator.alloc(PESP_Value, 1); // Allocating space for 1 item
    defer allocator.free(list);

    // Assign the value to the first index of the list
    list[0] = value;

    // Create a PESP_Value for the list
    const list_value = PESP_Value{ .list = list };

    // Convert the list_value to string
    const value_as_string = try list_value.to_string(allocator);
    defer allocator.free(value_as_string);

    try std.testing.expect(std.mem.eql(u8, "$10\r\nHelloWorld\r\n", value_as_string));
}
