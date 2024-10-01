const std = @import("std");

pub var kv_hashmap: ?std.StringHashMap([]const u8) = null;

pub fn init_kv() void {
    kv_hashmap = std.StringHashMap([]const u8).init(std.heap.page_allocator);
}

test "test_kv_hashmap" {
    init_kv();
    try kv_hashmap.?.put("key", "value");
}
