const std = @import("std");
const perfh = @import("perfect_hash_function.zig");

pub inline fn comptimeStringHashMap(comptime V: type) type {
    return struct {
        kvs: *const KVs = &empty_kvs,
        perf_hp: perfh.HashPramameters = undefined,

        const KV = struct {
            key: []const u8,
            value: V,
        };

        const KVs = struct {
            keys: [*]const []const u8,
            values: [*]const V,
            len: u32,
        };

        const empty_len_indexes = [0]u32{};
        const empty_keys = [0][]const u8{};
        const empty_vals = [0]V{};

        const empty_kvs = KVs{
            .keys = &empty_keys,
            .values = &empty_vals,
            .len = 0,
        };

        const Self = @This();

        pub inline fn comptimeInit(comptime kvs_list: anytype) Self {
            comptime {
                var self = Self{};
                if (kvs_list.len == 0) {
                    return self;
                }
                var keys: [kvs_list.len][]const u8 = undefined;
                var values: [kvs_list.len]V = undefined;
                for (kvs_list, 0..) |kv, i| {
                    keys[i] = kv.@"0";
                }
                self.perf_hp = perfh.findPerfectHashNumbers(&keys);
                for (kvs_list) |kv| {
                    const hash = perfh.Hash(kv.@"0", self.perf_hp);
                    keys[hash] = kv.@"0";
                    values[hash] = if (V == void) {} else kv.@"1";
                }
                const keys_ = keys;
                const values_ = values;
                self.kvs = &.{
                    .keys = &keys_,
                    .values = &values_,
                    .len = @intCast(kvs_list.len),
                };
                return self;
            }
        }

        pub fn getIndex(self: Self, key: []const u8) ?u64 {
            const hash = perfh.Hash(key, self.perf_hp);
            const k = self.kvs.keys[hash];
            if (std.ascii.eqlIgnoreCase(key, k)) {
                return hash;
            }
            return null;
        }

        pub fn get(self: Self, key: []const u8) ?V {
            return self.kvs.values[self.getIndex(key) orelse return null];
        }

        pub fn has(self: Self, key: []const u8) bool {
            return self.getIndex(key) != null;
        }
    };
}

test "test hashmap" {
    const kvs = &.{
        .{ "SET", "&set" },
        .{ "GET", "&get" },
        .{ "PING", "&ping" },
        .{ "CONFIG", "&config" },
    };
    const hashmap = comptimeStringHashMap([]const u8).comptimeInit(kvs);

    const value = hashmap.get("SET").?;

    try std.testing.expectEqualStrings(value, "&set");
}
