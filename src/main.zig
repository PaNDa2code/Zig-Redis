const std = @import("std");
const net = std.net;
const kv_storge = @import("kv_storge.zig");

const DBhashmap = kv_storge.DBhashmap;

const handle_client = @import("handle_client.zig").handle_client;
const signal_handler = @import("signal_handle.zig").signal_handler;

var active_clients: std.ArrayList(net.Server.Connection) = undefined;
var thread_pool: std.ArrayList(std.Thread) = undefined;

pub fn main() !void {
    const sa = std.os.linux.Sigaction{
        .handler = .{ .handler = signal_handler },
        .flags = 0,
        .mask = std.os.linux.empty_sigset,
        .restorer = null,
    };

    _ = std.os.linux.sigaction(2, &sa, null);

    const loopback = try net.Ip4Address.parse("127.0.0.1", 6379);
    const localhost = net.Address{ .in = loopback };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const check = gpa.deinit();
        std.debug.print("[!] GPA check: {any}\n", .{check});
    }

    const allocator = gpa.allocator();

    kv_storge.kv_hashmap = try allocator.create(DBhashmap);
    kv_storge.kv_hashmap.?.*.init(allocator);

    defer {
        kv_storge.kv_hashmap.?.deinit();
        allocator.destroy(kv_storge.kv_hashmap.?);
    }

    var server = try localhost.listen(.{
        .reuse_port = true,
    });

    defer server.deinit();
    const addr = server.listen_address;
    std.debug.print("Listing on {}\n", .{addr.getPort()});

    thread_pool = std.ArrayList(std.Thread).init(allocator);
    defer thread_pool.deinit();

    active_clients = std.ArrayList(net.Server.Connection).init(allocator);
    defer active_clients.deinit();

    while (true) {
        const client = try server.accept();
        const thread = try std.Thread.spawn(.{}, handle_client, .{client});
        thread.detach();
    }
}
