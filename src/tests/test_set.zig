const std = @import("std");
const main = @import("../main.zig").main;

test "test_set" {
    _ = try std.Thread.spawn(.{}, main, .{});

    std.time.sleep(10);
    // Define the server address and port (Redis default is 6379)
    const server_address = try std.net.Address.parseIp4("127.0.0.1", 6379);

    // Create a TCP socket and connect to the server
    var client = try std.net.tcpConnectToAddress(server_address);
    defer client.close();

    const num_requests: usize = 10_000; // Number of requests to send for the benchmark

    var i: usize = 0;
    while (i < num_requests) : (i += 1) {
        // Example Redis SET command to send
        const message = "*3\r\n$3\r\nSET\r\n$3\r\nkey\r\n$5\r\nvalue\r\n";

        // Send the message to the server
        _ = try client.write(message);

        // Read the response (typically "+OK\r\n" for Redis SET command)

        var buffer: [5]u8 = undefined;
        _ = try client.read(&buffer);
        try std.testing.expectEqualSlices(u8, "+OK\r\n", &buffer);
    }
}
