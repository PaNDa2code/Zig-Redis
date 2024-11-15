const std = @import("std");
const network = @import("network");
const net = std.net;

const builtin = @import("builtin");
const os_tag = builtin.os.tag;

const is_windows = os_tag == .windows;
const is_posix = os_tag == .linux or os_tag == .macos;

pub const MyServer = struct {
    allocator: std.mem.Allocator,
    address: std.net.Address,
    server: std.net.Server,
    listening: bool,

    pub const AcceptError = error{ SignalReceived, ConnectionFailed };

    pub fn init(self: *MyServer, address: std.net.Address, allocator: std.mem.Allocator) !void {
        const server = try address.listen(.{
            .reuse_port = true,
            // .force_nonblocking = true,
        });
        self.allocator = allocator;
        self.address = address;
        self.server = server;
        self.listening = true;
    }

    pub fn deinit(self: *MyServer) void {
        self.server.deinit();
    }

    pub fn accept(self: *MyServer) !std.net.Server.Connection {
        if (self.listening) {
            return self.server.accept();
        } else {
            return std.net.Server.AcceptError.SocketNotListening;
        }
    }

    pub fn stop_accepting(self: *MyServer) void {
        if (is_posix) {
            std.posix.shutdown(self.server.stream.handle, std.posix.ShutdownHow.recv) catch |err| {
                std.debug.print("{any}", .{err});
            };
        } else if (is_windows) {
            const err_code = std.os.windows.ws2_32.shutdown(self.server.stream.handle, std.os.windows.ws2_32.SD_RECEIVE);
            if (err_code != 0) {
                unreachable;
            }
        }
        self.listening = false;
    }
};
