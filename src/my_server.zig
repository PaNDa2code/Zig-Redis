const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;

const F_GETFL = 3;
const F_SETFL = 4;
const O_NONBLOCK = 2048;

const EPOLLIN = 0x001;
const EPOLL_CTL_ADD = 1;

pub const EpollServer = struct {
    StdServer: std.net.Server,
    pipe_fds: struct { read_fd: posix.fd_t, write_fd: posix.fd_t },
    epoll_events: [2]posix.system.epoll_event,
    epoll_fd: i32,

    pub const AcceptError = error{SignalReseved} || posix.PipeError;

    pub fn init(address: std.net.Address) !EpollServer {
        var server: EpollServer = undefined;
        server.StdServer = try address.listen(.{});
        const socket_fd = server.StdServer.stream.handle;
        const old_flags = try posix.fcntl(socket_fd, F_GETFL, 0);
        _ = try posix.fcntl(socket_fd, F_SETFL, old_flags | O_NONBLOCK);

        server.epoll_fd = try posix.epoll_create1(0);

        const pipe_fds = try posix.pipe();
        server.pipe_fds.read_fd = pipe_fds[0];
        server.pipe_fds.write_fd = pipe_fds[1];

        server.epoll_events[0] = posix.system.epoll_event{
            .events = EPOLLIN,
            .data = .{ .fd = socket_fd },
        };
        try posix.epoll_ctl(server.epoll_fd, EPOLL_CTL_ADD, socket_fd, &server.epoll_events[0]);

        server.epoll_events[1] = posix.system.epoll_event{
            .events = EPOLLIN,
            .data = .{ .fd = server.pipe_fds.read_fd },
        };

        try posix.epoll_ctl(server.epoll_fd, EPOLL_CTL_ADD, server.pipe_fds.read_fd, &server.epoll_events[1]);

        return server;
    }

    pub fn deinit(self: *EpollServer) void {
        posix.close(self.epoll_fd);
        posix.close(self.pipe_fds.read_fd);
        posix.close(self.pipe_fds.write_fd);
        self.StdServer.deinit();
    }

    pub fn accept(self: *EpollServer) !std.net.Server.Connection {
        var accepted_address: std.net.Address = undefined;
        var address_len: posix.socklen_t = @sizeOf(std.net.Address);
        while (true) {
            const events_count = posix.epoll_wait(self.epoll_fd, &self.epoll_events, 1000);
            if (events_count == -1) {
                return AcceptError.Unexpected;
            }

            for (0..events_count) |i| {
                if (self.epoll_events[i].events & EPOLLIN == 0) {
                    break;
                } else if (self.epoll_events[i].data.fd == self.StdServer.stream.handle) {
                    const client_fd = try posix.accept(self.StdServer.stream.handle, &accepted_address.any, &address_len, posix.SOCK.CLOEXEC);
                    return .{ .stream = .{ .handle = client_fd }, .address = accepted_address };
                } else if (self.epoll_events[i].data.fd == self.pipe_fds.read_fd) {
                    return AcceptError.SignalReseved;
                }
            }
        }
    }

    pub fn stop_accepting(self: *EpollServer) void {
        _ = posix.write(self.pipe_fds.write_fd, "\xFF") catch unreachable;
    }
};
