const std = @import("std");
const builtin = @import("builtin");

const os_tag = builtin.os.tag;
const posix = std.posix;
const Server = std.net.Server;

const F_GETFL = 3;
const F_SETFL = 4;
const O_NONBLOCK = 2048;

const EPOLLIN = 0x001;
const EPOLL_CTL_ADD = 1;

var pipe_fd_ptr: *const [2]posix.fd_t = undefined;

pub fn ServerSetNonBlockingAccept(server: Server) !void {
    const old_flags = try posix.fcntl(server.stream.handle, F_GETFL, 0);
    _ = try posix.fcntl(server.stream.handle, F_SETFL, old_flags | O_NONBLOCK);
}

pub const ServerEpollAcceptError = error{SignalReseved};

pub fn ServerEpollAccept(server: Server) !std.net.Server.Connection {
    const epoll_fd = try posix.epoll_create1(0);
    defer posix.close(epoll_fd);

    const pipe_fd: [2]posix.fd_t = try posix.pipe();
    defer {
        posix.close(pipe_fd[0]);
        posix.close(pipe_fd[1]);
    }

    pipe_fd_ptr = &pipe_fd;

    var epoll_events: [2]posix.system.epoll_event = undefined;

    epoll_events[0] = posix.system.epoll_event{
        .events = EPOLLIN,
        .data = .{ .fd = server.stream.handle },
    };

    try posix.epoll_ctl(epoll_fd, EPOLL_CTL_ADD, server.stream.handle, &epoll_events[0]);

    epoll_events[1] = posix.system.epoll_event{
        .events = EPOLLIN,
        .data = .{ .fd = pipe_fd[0] },
    };

    try posix.epoll_ctl(epoll_fd, EPOLL_CTL_ADD, pipe_fd[0], &epoll_events[1]);

    var accepted_address: std.net.Address = undefined;
    var address_len: posix.socklen_t = @sizeOf(std.net.Address);

    while (true) {
        const num_events = posix.epoll_wait(epoll_fd, &epoll_events, 0);
        if (num_events == -1) {
            return Server.AcceptError.Unexpected;
        }
        for (0..num_events) |_| {
            if (epoll_events[0].events & EPOLLIN != 0) {
                if (epoll_events[0].data.fd == pipe_fd[0]) {
                    return ServerEpollAcceptError.SignalReseved;
                } else {
                    const fd =
                        try posix.accept(server.stream.handle, &accepted_address.any, &address_len, posix.SOCK.CLOEXEC);
                    return std.net.Server.Connection{ .stream = .{ .handle = fd }, .address = accepted_address };
                }
            }
        }
    }
}

pub fn stopAccepting() void {
    _ = posix.write(pipe_fd_ptr[1], "\xFF") catch unreachable;
}
