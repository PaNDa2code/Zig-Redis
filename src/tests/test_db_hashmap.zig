const std = @import("std");
const DBhashmap = @import("../kv_storge.zig").DBhashmap;

test "database hashmap" {
    const allocator = std.testing.allocator;

    const db_hashmap_ptr = try allocator.create(DBhashmap);
    db_hashmap_ptr.init(allocator);

    var key: [10]u8 = std.mem.zeroes([10]u8);
    var value: [10]u8 = std.mem.zeroes([10]u8);

    for (0..10) |i| {
        const key_slice = try std.fmt.bufPrint(key[0..], "key{}", .{i});
        const value_slice = try std.fmt.bufPrint(value[0..], "value{}", .{i});

        _ = try db_hashmap_ptr.add(key_slice, value_slice);
    }

    for (0..10) |i| {
        const key_slice = try std.fmt.bufPrint(key[0..], "key{}", .{i});
        const value_slice = try std.fmt.bufPrint(value[0..], "value{}", .{i});

        const result = db_hashmap_ptr.get(key_slice);
        std.debug.assert(std.mem.eql(u8, value_slice, result.?));
    }

    db_hashmap_ptr.deinit();
    allocator.destroy(db_hashmap_ptr);
}
