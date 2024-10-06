const std = @import("std");
const builtin = @import("builtin");
const net = std.net;
const kv_storge = @import("kv_storge.zig");

const DBhashmap = kv_storge.DBhashmap;

const handle_client = @import("handle_client.zig").handle_client;
const signal_handle = @import("signal_handle.zig");
const my_server = @import("my_server.zig");

pub var server_ptr: ?*my_server.EpollServer = null;

var active_clients: std.ArrayList(net.Server.Connection) = undefined;
pub var thread_pool: std.ArrayList(std.Thread) = undefined;

const os_tag = builtin.os.tag;

pub fn main() !void {
    if (os_tag == .linux) {
        const sa = std.os.linux.Sigaction{
            .handler = .{ .handler = signal_handle.linux_signal_handler },
            .flags = 0,
            .mask = std.os.linux.empty_sigset,
            .restorer = null,
        };

        _ = std.os.linux.sigaction(2, &sa, null);
    } else if (os_tag == .windows) {
        try std.os.windows.SetConsoleCtrlHandler(signal_handle.windows_consle_ctrl_handler, true);
    }

    const loopback = try net.Ip4Address.parse("127.0.0.1", 6379);
    const localhost = net.Address{ .in = loopback };

    var gpa = std.heap.GeneralPurposeAllocator(.{ .verbose_log = false, .safety = false }){};
    defer {
        const check = gpa.deinit();
        if (check == .ok) {
            std.debug.print("[^-^] No leaks detected\n", .{});
        } else {
            std.debug.print("[ToT] GPA detected leaks\n", .{});
        }
    }

    const allocator = gpa.allocator();

    kv_storge.kv_hashmap = try allocator.create(DBhashmap);
    kv_storge.kv_hashmap.?.init(allocator);

    defer {
        kv_storge.kv_hashmap.?.deinit();
        allocator.destroy(kv_storge.kv_hashmap.?);
    }

    var server = try my_server.EpollServer.init(localhost);

    server_ptr = &server;

    defer server.deinit();

    const addr = server.StdServer.listen_address;
    std.debug.print("(⌐■_■) Listing on {any}\n", .{addr});

    thread_pool = std.ArrayList(std.Thread).init(allocator);
    defer thread_pool.deinit();

    active_clients = std.ArrayList(net.Server.Connection).init(allocator);
    defer active_clients.deinit();

    while (true) {
        const client = server.accept() catch |err| {
            if (err == my_server.EpollServer.AcceptError.SignalReseved) {
                break;
            } else {
                std.debug.print("error: {any}", .{err});
                continue;
            }
        };
        const thread = try std.Thread.spawn(.{}, handle_client, .{client});
        try thread_pool.append(thread);
    }

    for (thread_pool.items) |thread| {
        thread.join();
    }
}
