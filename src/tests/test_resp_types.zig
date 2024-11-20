const std = @import("std");
const data_types = @import("../resp_types.zig");
const RESP_Value = data_types.RESP_Value;
const PESP_Map = data_types.RESP_Map_Entry;

test "test data parsing and formatting" {
    const allocator = std.testing.allocator;

    const value_string = "*4\r\n$5\r\nHello\r\n$5\r\nWorld\r\n,0\r\n%2\r\n+key\r\n$5\r\nvalue\r\n$4\r\nisOk\r\n#t\r\n";
    var tok = std.mem.tokenizeAny(u8, value_string, "\r\n");

    const value_from_string = try RESP_Value.parseFromTokinizerAlloc(&tok, allocator);
    defer value_from_string.clean_up(allocator);

    try std.testing.expectFmt(value_string, "{}", .{value_from_string});
}
