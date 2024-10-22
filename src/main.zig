const std = @import("std");
const known_folders = @import("known-folders");
const Timer = @import("timer.zig").Timer;

const except = std.testing.expect;

const AppOptions = struct {
    flush: bool,
    new_line_on_quit: bool,
    run_socket: bool,
    format: [*]u8,
};

fn say_hello(timer: *Timer) void {
    std.log.debug("Hello to timer from on_cycle callback! {}", .{timer});
}

fn timer_loop(timer: *Timer) !void {
    while (true) {
        try timer.sleep_reduce_second(say_hello);
        std.debug.print("{}\n", .{timer});
    }
}

pub fn main() !void {
    var timer = Timer.create();
    _ = try std.Thread.spawn(.{}, timer_loop, .{&timer});
    var gpa_alloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa_alloc.deinit() == .ok);
    const gpa = gpa_alloc.allocator();
    {
        const args = try std.process.argsAlloc(gpa);
        defer std.process.argsFree(gpa, args);
        for (args) |arg| {
            std.debug.print("  {s}\n", .{arg});
        }
    }

    var port: u16 = 6660;
    var server = while (true) {
        const addr = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, port);
        const server = addr.listen(.{}) catch |err| {
            try except(err == error.AddressInUse);
            port += 1;
            continue;
        };
        break server;
    };
    std.log.info("Server is listening to port {d}", .{port});
    while (true) {
        var client = try server.accept();
        defer client.stream.close();
        const client_reader = client.stream.reader();
        const client_writer = client.stream.writer();
        const msg = try client_reader.readUntilDelimiterOrEofAlloc(gpa, '\n', 65536) orelse break;
        defer gpa.free(msg);

        std.log.info("Received message: \"{}\"", .{std.zig.fmtEscapes(msg)});

        const response = try std.fmt.allocPrint(gpa, "{s} to you too sir!\n", .{msg});
        defer gpa.free(response);

        try client_writer.writeAll(response);
    }
}
