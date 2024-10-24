const std = @import("std");
const known_folders = @import("known-folders");
const PomodoroTimer = @import("timer.zig").PomodoroTimer;
const PomodoroTimerConfig = @import("timer.zig").PomodoroTimerConfig;

const except = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const AppOptions = struct {
    flush: bool,
    new_line_on_quit: bool,
    run_socket: bool,
    format: [*]u8,
};

pub fn main() !void {
    var timer = PomodoroTimer.create_with_config(PomodoroTimerConfig{
        .paused = false,
        .pomodoro_seconds = 25,
        .long_break_seconds = 30,
        .short_break_seconds = 5,
        .session_count = 4,
    });
    var gpa_alloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa_alloc.deinit() == .ok);
    const gpa = gpa_alloc.allocator();

    var buff: [2]u8 = undefined;
    var server = try getServer();
    _ = try std.Thread.spawn(.{}, timerLoop, .{&timer});
    while (true) {
        var client = try server.accept();
        defer client.stream.close();
        const client_reader = client.stream.reader();
        const client_writer = client.stream.writer();
        const msg = client_reader.readUntilDelimiterOrEof(&buff, '\n') catch {
            try client_writer.writeAll("TOO LONG\n");
            continue;
        } orelse continue;
        std.log.info("Received message: \"{}\"", .{std.zig.fmtEscapes(msg)});

        const request_int = try std.fmt.parseInt(u16, msg, 10);
        if (std.meta.intToEnum(Request, request_int)) |request| {
            std.log.info("Message translated to \"{s}\"", .{@tagName(request)});
            try handleRequest(request, &timer);
            try client_writer.writeAll("OK\n");
        } else |err| {
            std.debug.print("{}\n", .{err});
            const response = try std.fmt.allocPrint(gpa, "Invalid request number {}\n", .{request_int});
            defer gpa.free(response);
            try client_writer.writeAll(response);
        }
    }
}

const Request = enum {
    TogglePause,
    Skip,
    CurrentReset,
    Pause,
    Unpause,
    TotalReset,
};

fn handleRequest(req: Request, timer: *PomodoroTimer) !void {
    switch (req) {
        .TogglePause => timer.paused = !timer.paused,
        .Skip => {
            on_cycle(timer);
            try timer.cycle_mode();
        },
        .CurrentReset => timer.update_duration(),
        .Pause => timer.paused = true,
        .Unpause => timer.paused = false,
        .TotalReset => timer.totalReset(),
    }
}

fn getServer() !std.net.Server {
    var port: u16 = 6660;
    const server = while (true) {
        const addr = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, port);
        const server = addr.listen(.{}) catch |err| {
            try except(err == error.AddressInUse);
            port += 1;
            continue;
        };
        break server;
    };
    std.log.info("Server is listening to port {d}", .{port});
    return server;
}

fn on_cycle(timer: *PomodoroTimer) void {
    std.log.debug("Hello to timer from on_cycle callback! {}", .{timer});
}

fn on_tick(timer: *PomodoroTimer) void {
    expectEqual(false, timer.paused) catch |err| {
        std.log.err("Paused assertion failed: {}", .{err});
        std.process.exit(1);
    };
    std.debug.print("{}\n", .{timer});
}

fn timerLoop(timer: *PomodoroTimer) !void {
    while (true) {
        try timer.tick(on_tick, on_cycle);
    }
}
