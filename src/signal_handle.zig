const std = @import("std");

pub fn signal_handler(sig: i32) callconv(.C) void {
    _ = sig; // autofix

    const stdout = std.io.getStdOut();
    const stdin = std.io.getStdIn();
    defer stdout.close();
    defer stdin.close();

    _ = stdout.write("\n[!] Reseved SIGINT\n[?] Do you want to shutdown the database? (y/n) ") catch unreachable;
    var answer = std.mem.zeroes([2]u8);
    _ = stdin.read(answer[0..]) catch unreachable;

    if (answer[0] == 'y') {
        std.posix.exit(1);
    }
}
