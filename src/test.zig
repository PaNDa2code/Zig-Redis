const std = @import("std");
const testing = std.testing;

const resp_types_test = @import("tests/test_resp_types.zig");

test {
    std.testing.refAllDecls(resp_types_test);
}
