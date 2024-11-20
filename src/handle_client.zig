const std = @import("std");
const net = std.net;

const db = @import("db.zig");

const RESP_Types = @import("resp_types.zig");
const RESP_Value = RESP_Types.RESP_Value;

const CommandFunctionType = fn (net.Server.Connection, *const RESP_Value) void;
const CommandLookUpOb = struct { name: []const u8, fn_ptr: *const CommandFunctionType };

const allocator = std.heap.c_allocator;

const CommandLookUpTable = &[_]CommandLookUpOb{
    .{ .name = "GET", .fn_ptr = &get },
    .{ .name = "PING", .fn_ptr = &ping },
    .{ .name = "CONFIG", .fn_ptr = &config },
    .{ .name = "SET", .fn_ptr = &set },
};

pub fn handle_client(client: net.Server.Connection) !void {
    defer client.stream.close();
    var buffer: [1024]u8 = undefined;

    while (true) {
        const bytes = client.stream.read(&buffer) catch 0;
        if (bytes == 0) {
            break;
        }

        const command_value = try RESP_Value.parseFromSliceAlloc(&buffer, allocator);
        defer command_value.clean_up(allocator);

        const command_name_slice = command_value.list[0].string;
        const command_function = command_lookup(command_name_slice);

        if (command_function != null) {
            command_function.?(client, &command_value);
        } else {
            _ = try client.stream.write("-Unknown command\r\n");
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

fn ping(client: net.Server.Connection, command_value: *const RESP_Value) void {
    // Write the response and ignore any potential errors
    if (command_value.list.len > 1) {
        client.stream.writer().print("{}", .{command_value.list[1]}) catch {};
    } else {
        client.stream.writeAll("+PONG\r\n") catch {};
    }
}

fn config(client: net.Server.Connection, command_value: *const RESP_Value) void {
    _ = command_value; // autofix
    _ = client.stream.write("*1\r\n$5\r\nHello\r\n") catch {};
}

fn set(client: net.Server.Connection, command_value: *const RESP_Value) void {
    if (command_value.list.len < 3) {
        _ = client.stream.writeAll("-Command SET expicted 2 arguments") catch {};
        return;
    }
    const key = command_value.list[1].string;
    const value = command_value.list[2];
    const add_return = db.db_hashmap_ptr.?.add(key, value);

    add_return catch {
        _ = client.stream.write("-\r\n") catch {};
        return;
    };
    _ = client.stream.write("+OK\r\n") catch {};
}

fn get(client: net.Server.Connection, command_value: *const RESP_Value) void {
    const w = client.stream.writer();
    var buf_w = std.io.bufferedWriter(w);
    var writer = buf_w.writer();

    const key = command_value.list[1].string;

    const value = db.db_hashmap_ptr.?.get(key);

    if (value) |val| {
        writer.print("{}", .{val}) catch {};
    } else {
        _ = writer.write("$-1\r\n") catch {};
    }
    buf_w.flush() catch {};
}
