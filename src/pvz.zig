const std = @import("std");
const except = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const PomodoroTimer = @import("timer.zig").PomodoroTimer;

pub const MAX_REQ_LEN = 1000;

pub fn getServer() !std.net.Server {
    var port: u16 = 6660;
    const server = while (true) {
        const addr = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, port);
        const server = addr.listen(.{}) catch |err| {
            try expectEqual(error.AddressInUse, err);
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
    const out = std.io.getStdOut().writer();
    out.print("{}\n", .{timer}) catch {};
}

pub fn timerLoop(timer: *PomodoroTimer) !void {
    while (true) {
        try timer.tick(on_tick, on_cycle);
    }
}

pub const Request = enum {
    toggle,
    skip,
    current_reset,
    pause,
    unpause,
    reset,
    seek,
    seek_back,
    quit,
    get_timer,
};

pub fn handleRequest(req: Request, timer: *PomodoroTimer, writer: anytype) !bool {
    var ok = true;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();
    switch (req) {
        .toggle => timer.paused = !timer.paused,
        .skip => {
            on_cycle(timer);
            try timer.cycle_mode();
        },
        .current_reset => timer.update_duration(),
        .pause => timer.paused = true,
        .unpause => timer.paused = false,
        .reset => timer.init(),
        .seek => {
            timer.seek(5);
            on_tick(timer);
        },
        .seek_back => {
            timer.seek_back(5);
            on_tick(timer);
        },
        .quit => {
            return true;
        },
        .get_timer => {
            ok = false;
            const msg = try std.fmt.allocPrint(alloc, "{}-{}-{}-{}\n", .{ timer.seconds, timer.session_count, timer.paused, @intFromEnum(timer.mode) });
            defer alloc.free(msg);
            try writer.writeAll(msg);
        },
    }
    if (ok) {
        try writer.writeAll("OK\n");
    }
    return false;
}
