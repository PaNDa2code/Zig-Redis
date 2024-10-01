const std = @import("std");
const net = std.net;

var rwlock: std.Thread.RwLock = .{};
var kv_hashmap = &@import("kv_storge.zig").kv_hashmap;

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
    var buffer: [1024]u8 = undefined;
    while (true) {
        const bytes = try client.stream.read(&buffer);
        if (bytes == 0) {
            break;
        }

        // Tokenize the input to get the command name
        var it = std.mem.tokenizeAny(u8, buffer[0..bytes], "\r\n");

        _ = it.next();
        _ = it.next();
        const command_name = it.next().?;

        // Lookup the command function
        const command_function = command_lookup(command_name);

        if (command_function != null) {
            // Call the command function if found
            command_function.?(client, &it);
        } else {
            // Handle unknown command case
            _ = try client.stream.write("+-Unknown command\r\n");
        }
    }

    // Close the connection
    defer client.stream.close();
}

fn command_lookup(command: []const u8) ?*const CommandFunctionType {
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
    const key = tokens.next();
    _ = tokens.next();
    _ = tokens.next();
    const value = tokens.next();

    if (key == null or value == null) {
        _ = client.stream.write("-error\r\n") catch {};
        return;
    }

    rwlock.lock();
    const put_return = kv_hashmap.*.?.put(key.?, value.?);
    rwlock.unlock();

    put_return catch {
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

    rwlock.lockShared();
    const value = kv_hashmap.*.?.get(key.?);
    rwlock.unlockShared();

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