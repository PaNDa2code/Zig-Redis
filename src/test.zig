const std = @import("std");
const testing = std.testing;

const set_test = @import("tests/test_set.zig");
const db_hashmap_test = @import("tests/test_db_hashmap.zig");
const data_types_test = @import("tests/test_data_types.zig");

test {
    std.testing.refAllDecls(set_test);
    std.testing.refAllDecls(db_hashmap_test);
    std.testing.refAllDecls(data_types_test);
}
