const std = @import("std");
const data_types = @import("../data_types.zig");
const RESP_Value = data_types.RESP_Value;
const PESP_Map = data_types.RESP_Map;

test "test_data_types" {
    const allocator = std.testing.allocator;

    // Create a string (heap-allocated)
    const string = try allocator.dupe(u8, "HelloWorld");
    defer allocator.free(string);

    // Create a PESP_Value with the string
    const value = RESP_Value{ .string = string };

    // Allocate memory for a list of PESP_Value
    var list = try allocator.alloc(RESP_Value, 1); // Allocating space for 1 item
    defer allocator.free(list);

    // Assign the value to the first index of the list
    list[0] = value;

    // Create a PESP_Value for the list
    const list_value = RESP_Value{ .list = list };

    // Convert the list_value to string
    const value_as_string = try list_value.toStringAlloc(allocator);
    defer allocator.free(value_as_string);

    try std.testing.expectEqualSlices(u8, "$10\r\nHelloWorld\r\n", value_as_string);

    const allocator2 = std.heap.page_allocator;

    const value_string = "*4\r\n$5\r\nHello\r\n$5\r\nWorld\r\n,10.18\r\n%1\r\n+key\r\n$5\r\nvalue\r\n";
    var tok = std.mem.tokenizeAny(u8, value_string, "\r\n");
    const value_from_string = try RESP_Value.fromToknizerAlloc(&tok, allocator2);
    std.debug.print("{any}\n", .{value_from_string});
}
