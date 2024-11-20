const std = @import("std");
const net = std.net;

const db = @import("db.zig");

const RESP_Types = @import("resp_types.zig");
const RESP_Value = RESP_Types.RESP_Value;

const tokenizerType = std.mem.TokenIterator(u8, std.mem.DelimiterType.any);
const CommandFunctionType = fn (net.Server.Connection, *RESP_Value) void;
const CommandLookUpOb = struct { name: []const u8, fn_ptr: *const CommandFunctionType };

const allocator = std.heap.c_allocator;

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
        const command_value = try RESP_Value.parseFromTokinizerAlloc(&it, allocator);
        const command_name_slice = command_value.list[0].string;
        const command_function = command_lookup(command_name_slice);

        if (command_function != null) {
            command_function.?(client, command_value);
        } else {
            _ = try client.stream.write("+-Unknown command\r\n");
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

fn ping(client: net.Server.Connection, command_value: *RESP_Value) void {
    // Write the response and ignore any potential errors
    if (command_value.list.len > 1) {
        client.stream.writer().print("{}", .{command_value.list[1]}) catch {};
    } else {
        client.stream.writeAll("+PONG\r\n") catch {};
    }
}

fn config(client: net.Server.Connection, command_value: *RESP_Value) void {
    _ = command_value; // autofix
    _ = client.stream.write("*1\r\n$5\r\nHello\r\n") catch {};
}

fn set(client: net.Server.Connection, command_value: *RESP_Value) void {
    if (command_value.list.len < 3) {
        _ = client.stream.writeAll("-Command SET expicted 2 arguments") catch {};
        return;
    }
    const key = command_value.list[1].string;
    const value = command_value.list[2];
    const add_return = db.db_hashmap_ptr.?.add(key.?, value.?);

    add_return catch {
        _ = client.stream.write("-\r\n") catch {};
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

    const value = db.db_hashmap_ptr.?.get(key.?);

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
