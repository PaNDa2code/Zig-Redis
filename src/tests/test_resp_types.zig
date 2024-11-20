const std = @import("std");
const data_types = @import("../resp_types.zig");
const RESP_Value = data_types.RESP_Value;
const PESP_Map = data_types.RESP_Map_Entry;

test "test data parsing and formatting" {
    const allocator = std.testing.allocator;

    const value_string =
        "*5\r\n$5\r\nHello\r\n$5\r\nWorld\r\n,1.0005084\r\n%2\r\n+key\r\n$5\r\nvalue\r\n$4\r\nisOk\r\n#t\r\n_\r\n";

    const value_parsed = try RESP_Value.parseFromSliceAlloc(value_string, allocator);

    defer value_parsed.clean_up(allocator);

    try std.testing.expectFmt(value_string, "{}", .{value_parsed});

    try std.testing.expectEqualStrings(value_parsed.list[0].string, "Hello");
    try std.testing.expectEqualStrings(value_parsed.list[1].string, "World");
    try std.testing.expectEqualStrings(value_parsed.list[3].map[0].key.simple_string, "key");
    try std.testing.expectEqualStrings(value_parsed.list[3].map[0].value.string, "value");
    try std.testing.expectEqualStrings(value_parsed.list[3].map[1].key.string, "isOk");

    try std.testing.expectEqual(value_parsed.list[3].map[1].value.bool, true);
    try std.testing.expectEqual(value_parsed.list[2].double, 1.0005084);

    try std.testing.expect(value_parsed.list[4].null == undefined);
}
