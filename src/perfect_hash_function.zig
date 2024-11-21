const std = @import("std");

pub const HashPramameters = struct {
    a: u64,
    b: u64,
    p: u64,
    m: u32,
};

pub inline fn Hash(string: []const u8, n: HashPramameters) u64 {
    var hash: u64 = 0;
    for (0..string.len) |i| {
        hash +%= string[i] * (std.math.pow(u64, 10, i));
    }
    hash *%= n.a;
    hash +%= n.b;
    hash %= n.p;
    hash %= n.m;
    return hash;
}

pub fn findPerfectHashNumbers(comptime strings: []const []const u8) HashPramameters {
    @setEvalBranchQuota(1000000);
    var hash_collision = false;
    var rand = std.Random.DefaultPrng.init(0xacf12);
    var bool_list = [1]bool{false} ** strings.len;
    var hash_numbers: HashPramameters = .{ .a = 0, .b = 0, .p = 0, .m = strings.len };

    while (true) {
        hash_numbers.a = rand.random().int(u64);
        hash_numbers.b = rand.random().int(u64);
        hash_numbers.p = rand.random().int(u64);
        for (strings) |string| {
            const hash = Hash(string, hash_numbers);
            if (bool_list[hash]) {
                hash_collision = true;
                break;
            }
            bool_list[hash] = true;
        }
        if (!hash_collision) {
            break;
        }
        for (0..strings.len) |i| {
            bool_list[i] = false;
        }
        hash_collision = false;
    }
    return hash_numbers;
}

test {
    const words: []const []const u8 = &.{ "GET", "SET", "CONFIG", "PING" };

    var keys = [1][]const u8{undefined} ** words.len;
    const perfect_hash_numbers = comptime findPerfectHashNumbers(words);
    for (words) |word| {
        const hash = Hash(word, perfect_hash_numbers);
        keys[hash] = word;
    }
    std.debug.print("{s}\n", .{keys});
}
