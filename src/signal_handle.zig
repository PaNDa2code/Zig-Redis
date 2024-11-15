const std = @import("std");
const builtin = @import("builtin");

pub fn linux_signal_handler(sig: i32) callconv(.C) void {
    _ = sig; // autofix
    signal_handler();
}

pub fn windows_consle_ctrl_handler(sig: std.os.windows.DWORD) callconv(.C) std.os.windows.BOOL {
    _ = sig; // autofix
    signal_handler();
    return std.os.windows.TRUE;
}

fn signal_handler() void {
    const stdout = std.io.getStdOut();
    const stdin = std.io.getStdIn();

    _ = stdout.writeAll("\n[!] Reseved SIGINT\n[?] Do you want to shutdown the database? (y/n) ") catch unreachable;
    var answer = std.mem.zeroes([2]u8);
    _ = stdin.read(answer[0..]) catch unreachable;

    if (answer[0] == 'y') {
        @import("main.zig").server.stop_accepting();
    }
}
