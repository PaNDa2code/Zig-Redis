const std = @import("std");
const testing = std.testing;

const set_test = @import("tests/test_set.zig");
const db_hashmap_test = @import("tests/test_db_hashmap.zig");
const resp_types_test = @import("tests/test_resp_types.zig");

test {
    // std.testing.refAllDecls(set_test);
    // std.testing.refAllDecls(db_hashmap_test);
    std.testing.refAllDecls(resp_types_test);
}
