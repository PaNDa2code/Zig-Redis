const std = @import("std");
const net = std.net;
const kv_storge = @import("kv_storge.zig");

const DBhashmap = kv_storge.DBhashmap;

const handle_client = @import("handle_client.zig").handle_client;

pub fn main() !void {
    const loopback = try net.Ip4Address.parse("127.0.0.1", 6379);
    const localhost = net.Address{ .in = loopback };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    kv_storge.kv_hashmap = try allocator.create(DBhashmap);
    kv_storge.kv_hashmap.?.*.init(allocator);

    var server = try localhost.listen(.{
        .reuse_port = true,
    });

    defer server.deinit();
    const addr = server.listen_address;
    std.debug.print("Listing on {}\n", .{addr.getPort()});

    var thread_pool = std.ArrayList(std.Thread).init(allocator);
    defer thread_pool.deinit();

    while (true) {
        const client = try server.accept();
        const thread = try std.Thread.spawn(.{}, handle_client, .{client});
        thread.detach();
    }

    kv_storge.kv_hashmap.?.deinit();
    allocator.free(kv_storge.kv_hashmap);
}
