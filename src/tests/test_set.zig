const std = @import("std");
const main = @import("../main.zig").main;

test "test_set" {
    // const allocator = std.testing.allocator;

    _ = try std.Thread.spawn(.{}, main, .{});

    std.time.sleep(3);
    // Define the server address and port (Redis default is 6379)
    const server_address = try std.net.Address.parseIp4("127.0.0.1", 6379);

    // Create a TCP socket and connect to the server
    var client = try std.net.tcpConnectToAddress(server_address);
    defer client.close();

    const num_requests: usize = 10_000; // Number of requests to send for the benchmark

    // Start the timer for benchmarking
    // const start_time = std.time.milliTimestamp();

    var i: usize = 0;
    while (i < num_requests) : (i += 1) {
        // Example Redis SET command to send
        const message = "*3\r\n$3\r\nSET\r\n$3\r\nkey\r\n$5\r\nvalue\r\n";

        // Send the message to the server
        _ = try client.write(message);

        // Read the response (typically "+OK\r\n" for Redis SET command)
        var buffer: [16]u8 = undefined;
        _ = try client.read(&buffer);
    }

    // End the timer
    // const end_time = std.time.milliTimestamp();

    // Calculate the total time taken
    // const total_time = end_time - start_time;
    // const requests_per_second = try std.math.divCeil(i64, num_requests * 1000, total_time);

    // std.debug.print("Completed {d} requests in {d} ms.\n", .{ num_requests, total_time });
    // std.debug.print("Requests per second: {d} req/sec.\n", .{requests_per_second});
}
