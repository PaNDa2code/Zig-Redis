const std = @import("std");
const RESP_Value = @import("data_types.zig").RESP_Value;

pub const DBhashmap = struct {
    kv_hashmap: std.StringHashMap(RESP_Value),
    rwlock: std.Thread.RwLock,
    allocator: std.mem.Allocator,

    pub fn init(self: *DBhashmap, allocator: std.mem.Allocator) void {
        self.kv_hashmap = std.StringHashMap(RESP_Value).init(allocator);
        self.rwlock = .{};
        self.allocator = allocator;
    }

    pub fn deinit(self: *DBhashmap) void {
        // no unlocks sence, there is no access after this call
        self.rwlock.lock();
        var iterator = self.kv_hashmap.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.kv_hashmap.deinit();
    }

    pub fn add(self: *DBhashmap, key: []const u8, value: RESP_Value) !void {
        const key_copy = self.allocator.dupe(u8, key) catch unreachable;
        const value_copy = self.allocator.dupe(RESP_Value, value) catch unreachable;

        errdefer {
            self.allocator.free(key_copy);
            self.allocator.free(value_copy);
        }

        self.rwlock.lock();
        const entry = self.kv_hashmap.fetchPut(key_copy, value_copy);
        self.rwlock.unlock();

        if (try entry) |kv| {
            self.allocator.free(key_copy);
            self.allocator.free(kv.value);
        }
    }

    pub fn get(self: *DBhashmap, key: []const u8) ?RESP_Value {
        self.rwlock.lockShared();
        const value = self.kv_hashmap.get(key);
        self.rwlock.unlockShared();
        return value;
    }

    pub fn getStrAlloc(self: *DBhashmap, key: []const u8) ?[]const u8 {
        self.rwlock.lockShared();
        const value = self.kv_hashmap.get(key);
        self.rwlock.unlockShared();
        if (value) |v| {
            return v.to_string(self.allocator) catch {};
        } else {
            return null;
        }
    }
};

pub var db_hashmap_ptr: ?*DBhashmap = null;

test "test DBhashmap" {
    const allocator = std.testing.allocator;
    var hashmap: DBhashmap = undefined;

    hashmap.init(allocator);
    defer hashmap.deinit();

    for (0..100) |_| {
        try hashmap.add("key", "value");
    }
}
