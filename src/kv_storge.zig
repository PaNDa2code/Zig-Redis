const std = @import("std");

pub const DBhashmap = struct {
    kv_hashmap: std.StringHashMap([]const u8),
    rwlock: std.Thread.RwLock,
    allocator: std.mem.Allocator,

    pub fn init(self: *DBhashmap, allocator: std.mem.Allocator) void {
        self.kv_hashmap = std.StringHashMap([]const u8).init(allocator);
        self.rwlock = .{};
        self.allocator = allocator;
    }

    pub fn deinit(self: *DBhashmap) void {
        self.rwlock.lock();
        var iterator = self.kv_hashmap.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.kv_hashmap.deinit();
        self.rwlock.unlock();
    }

    pub fn add(self: *DBhashmap, key: []const u8, value: []const u8) !void {
        const key_copy = try self.allocator.dupe(u8, key);
        const value_copy = try self.allocator.dupe(u8, value);

        self.rwlock.lock();
        self.kv_hashmap.put(key_copy, value_copy) catch unreachable;
        self.rwlock.unlock();
    }
    pub fn get(self: *DBhashmap, key: []const u8) ?[]const u8 {
        self.rwlock.lockShared();
        const value = self.kv_hashmap.get(key);
        self.rwlock.unlockShared();
        return value;
    }
};

pub var kv_hashmap: ?*DBhashmap = null;

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
