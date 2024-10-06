const std = @import("std");
const net = std.net;
const kv_storge = @import("kv_storge.zig");

const tokenizerType = std.mem.TokenIterator(u8, std.mem.DelimiterType.any);
const CommandFunctionType = fn (net.Server.Connection, *tokenizerType) void;
const CommandLookUpOb = struct { name: []const u8, fn_ptr: *const CommandFunctionType };

const CommandLookUpTable = &[_]CommandLookUpOb{
    .{ .name = "PING", .fn_ptr = &ping },
    .{ .name = "CONFIG", .fn_ptr = &config },
    .{ .name = "SET", .fn_ptr = &set },
    .{ .name = "GET", .fn_ptr = &get },
};

pub fn handle_client(client: net.Server.Connection) !void {
    defer client.stream.close();
    var buffer: [1024]u8 = undefined;

    while (true) {
        const bytes = client.stream.read(&buffer) catch 0;
        if (bytes == 0) {
            break;
        }

        var it = std.mem.tokenizeAny(u8, buffer[0..bytes], "\r\n");

        _ = it.next();
        _ = it.next();
        const command_name = it.next() orelse "";

        const command_function = command_lookup(command_name);

        if (command_function != null) {
            command_function.?(client, &it);
        } else {
            _ = try client.stream.write("+-Unknown command\r\n");
        }
    }
}

fn remove_from_thread_bool(thread_pool: *std.ArrayList(std.Thread)) void {
    const curr_thread = std.Thread.getCurrentId();

    for (thread_pool.items, 0..thread_pool.items.len) |thread, i| {
        if (thread.Id == curr_thread) {
            _ = thread_pool.swapRemove(i);
        }
    }
}

fn command_lookup(command: []const u8) ?*const CommandFunctionType {
    if (command.len == 0) {
        return null;
    }
    for (CommandLookUpTable) |comm| {
        if (std.ascii.eqlIgnoreCase(command, comm.name)) {
            return comm.fn_ptr;
        }
    }
    return null;
}

fn ping(client: net.Server.Connection, tokens: *tokenizerType) void {
    // Write the response and ignore any potential errors
    if (tokens.next() != null) {
        _ = client.stream.writer()
            .print("${}\r\n{s}\r\n", .{ tokens.peek().?.len, tokens.peek().? }) catch {};
    } else {
        _ = client.stream.write("+PONG\r\n") catch {};
    }
}

fn config(client: net.Server.Connection, tokens: *tokenizerType) void {
    _ = tokens; // autofix
    _ = client.stream.write("*1\r\n$5\r\nHello\r\n") catch {};
}

fn set(client: net.Server.Connection, tokens: *tokenizerType) void {
    _ = tokens.next();
    const key = tokens.next();
    _ = tokens.next();
    // _ = tokens.next();
    const value = tokens.next();

    if (key == null or value == null) {
        _ = client.stream.write("-error\r\n") catch {};
        return;
    }

    const add_return = kv_storge.kv_hashmap.?.add(key.?, value.?);

    add_return catch {
        _ = client.stream.write("-error\r\n") catch {};
        return;
    };
    _ = client.stream.write("+OK\r\n") catch {};
}

fn get(client: net.Server.Connection, tokens: *tokenizerType) void {
    const key = tokens.next();
    var writer = client.stream.writer();

    if (key == null) {
        _ = writer.write("-error\r\n") catch {};
        return;
    }

    const value = kv_storge.kv_hashmap.?.get(key.?);

    if (value) |val| {
        write_bluk_string(writer, val) catch {};
    } else {
        _ = writer.write("$-1\r\n") catch {};
    }
}

fn write_bluk_string(writer: net.Stream.Writer, string: []const u8) !void {
    var buffered_writer = std.io.bufferedWriter(writer);
    try buffered_writer.writer().print("${}\r\n{s}\r\n", .{ string.len, string });
    try buffered_writer.flush();
}
