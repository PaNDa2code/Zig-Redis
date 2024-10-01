const std = @import("std");
const net = std.net;
const init_kv = @import("kv_storge.zig").init_kv;

const handle_client = @import("handle_client.zig").handle_client;

pub fn main() !void {
    const loopback = try net.Ip4Address.parse("127.0.0.1", 6379);
    const localhost = net.Address{ .in = loopback };

    var server = try localhost.listen(.{
        .reuse_port = true,
    });

    defer server.deinit();

    const addr = server.listen_address;
    std.debug.print("Listing on {}\n", .{addr.getPort()});

    init_kv();

    while (true) {
        const client = try server.accept();
        const thread = try std.Thread.spawn(.{}, handle_client, .{client});
        _ = thread; // autofix
    }
}
