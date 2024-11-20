const std = @import("std");
const net = std.net;
const db = @import("db.zig");
const RESP_Types = @import("resp_types.zig");
const RESP_Value = RESP_Types.RESP_Value;

const CommandFunctionType = fn (std.io.AnyWriter, *const RESP_Value) void;
const CommandLookUpOb = struct { name: []const u8, fn_ptr: *const CommandFunctionType };

const CommandLookUpMap = std.StaticStringMapWithEql(*const CommandFunctionType, std.ascii.eqlIgnoreCase).initComptime(.{
    .{ "SET", &set },
    .{ "GET", &get },
    .{ "PING", &ping },
    .{ "CONFIG", &config },
});

pub fn handle_client(client: net.Server.Connection, allocator: std.mem.Allocator) !void {
    defer client.stream.close();
    var buffer: [1024]u8 = undefined;

    const stream_writer = client.stream.writer();
    var buffered_writer = std.io.bufferedWriter(stream_writer);
    const writer = buffered_writer.writer().any();

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
            command_function.?(writer, &command_value);
        } else {
            _ = try writer.print("-ERR Unknown command '{s}'\r\n", .{command_name_slice});
        }

        try buffered_writer.flush();
    }
}

fn command_lookup(command: []const u8) ?*const CommandFunctionType {
    if (command.len == 0) {
        return null;
    }
    return CommandLookUpMap.get(command);
}

fn ping(writer: std.io.AnyWriter, command_value: *const RESP_Value) void {
    // Write the response and ignore any potential errors
    if (command_value.list.len > 1) {
        writer.print("{}", .{command_value.list[1]}) catch {};
    } else {
        writer.writeAll("+PONG\r\n") catch {};
    }
}

fn config(writer: std.io.AnyWriter, command_value: *const RESP_Value) void {
    _ = command_value; // autofix
    _ = writer.writeAll("*1\r\n$5\r\nHello\r\n") catch {};
}

fn set(writer: std.io.AnyWriter, command_value: *const RESP_Value) void {
    if (command_value.list.len < 3) {
        _ = writer.writeAll("-ERR Command \'SET\' expicted 2 arguments [key] [value]\r\n") catch {};
        return;
    }
    const key = command_value.list[1].string;
    const value = command_value.list[2];
    const add_return = db.db_hashmap_ptr.?.add(key, value);

    add_return catch {
        _ = writer.writeAll("-\r\n") catch {};
        return;
    };
    _ = writer.writeAll("+OK\r\n") catch {};
}

fn get(writer: std.io.AnyWriter, command_value: *const RESP_Value) void {
    if (command_value.list.len < 2) {
        writer.writeAll("-ERR Command \'GET\' expicted 1 arguments [key]\r\n") catch {};
        return;
    }
    const key = command_value.list[1].string;
    const value = db.db_hashmap_ptr.?.get(key);
    if (value) |val| {
        writer.print("{}", .{val}) catch {};
    } else {
        _ = writer.write("$-1\r\n") catch {};
    }
}
