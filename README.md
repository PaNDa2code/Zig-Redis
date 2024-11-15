# Zig Database Server

This project is a basic in-memory database server implemented in the [Zig programming language](https://ziglang.org/). It mimics a simplified Redis-like architecture, supporting basic commands like `SET`, `GET`, and `PING`. The server uses multithreading to handle client connections and includes a custom hashmap implementation for storing key-value pairs. 

## Features

- **In-memory Key-Value Store**: 
  - Stores keys and values in memory using `DBhashmap`, a structure built around `std.StringHashMap`.
  - Provides thread-safe access with read-write locks.

- **Basic Commands**:
  - `PING`: Responds with a "PONG".
  - `SET key value`: Adds or updates a key-value pair.
  - `GET key`: Retrieves the value associated with a key.

- **Thread-Safe Multithreading**:
  - Uses `std.Thread` for handling multiple client connections concurrently.
  - Includes thread-safe management for active client and thread pools.

- **Signal Handling**:
  - Gracefully handles signals like `SIGINT` to allow clean shutdowns.

- **Memory Management**:
  - Supports custom allocators for debugging and performance.
  - Tracks memory allocation during tests to ensure no memory leaks.

- **Cross-Platform Compatibility**:
  - Runs on Linux, macOS, and Windows.

## Project Structure

### Source Files

- **`src/db.zig`**: 
  - Implements `DBhashmap`, the core data structure for storing key-value pairs.
  - Includes `add`, `get`, and initialization/de-initialization functions.

- **`src/handle_client.zig`**:
  - Handles client commands by tokenizing input and executing appropriate functions.
  - Includes functions for `PING`, `SET`, and `GET`.

- **`src/main.zig`**:
  - The entry point of the application.
  - Sets up the server, initializes resources, and manages the main event loop.

- **`src/my_server.zig`**:
  - Encapsulates server operations, including accepting connections and shutting down.
  - Provides OS-specific handling for shutting down sockets.

- **`src/signal_handle.zig`**:
  - Implements signal handling for graceful shutdowns on Linux and Windows.

### Test Files

- **`src/tests/test_db_hashmap.zig`**:
  - Tests `DBhashmap` for functionality and memory safety.

- **`src/tests/test_set.zig`**:
  - Tests the `SET` command functionality.

- **`src/test.zig`**:
  - Runs all tests defined in the project.

## Running the Server

1. **Build the Project**:
   ```bash
   zig build
   ```

2. **Run the Server**:
   ```bash
   zig-out/bin/server
   ```

3. **Connect to the Server**:
   Use tools like `telnet` or a custom client to connect to `127.0.0.1:6379` and issue commands:
   ```bash
   telnet 127.0.0.1 6379
   ```

## Commands

- `PING`: Test server responsiveness.
  ```
  > PING
  < +PONG
  ```

- `SET key value`: Store a key-value pair.
  ```
  > SET mykey myvalue
  < +OK
  ```

- `GET key`: Retrieve the value of a key.
  ```
  > GET mykey
  < $7
  < myvalue
  ```

## Testing

Run the included tests to ensure functionality and memory safety:
```bash
zig test src/test.zig
```

## Memory Debugging

The project supports memory tracking during debug builds using `std.heap.GeneralPurposeAllocator`. In non-debug builds, it uses the faster `std.heap.raw_c_allocator`.

## Future Enhancements

- Support for more commands (e.g., `DELETE`, `EXISTS`).
- Persistent storage for data across server restarts.
- Optimizations for multithreaded performance.
- Improved client protocol handling for more robust communication.

---

Enjoy exploring this lightweight and extensible database server in Zig! 🎉
