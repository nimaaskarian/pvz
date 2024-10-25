const std = @import("std");
const except = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const PomodoroTimer = @import("timer.zig").PomodoroTimer;

pub const MAX_REQ_LEN = 2;

pub fn getServer() !std.net.Server {
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
};

pub fn handleRequest(req: Request, timer: *PomodoroTimer) !void {
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
    }
}
