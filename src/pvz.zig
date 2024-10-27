const std = @import("std");
const utils = @import("utils.zig");
const except = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const pomodoro_timer = @import("timer.zig");
const PomodoroTimer = pomodoro_timer.PomodoroTimer;
const formatStr = pomodoro_timer.formatStr;

pub const MAX_REQ_LEN = 2;

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
    std.log.debug("on_cycle callback! timer: {}", .{timer});
}

fn on_tick(timer: *PomodoroTimer, alloc: std.mem.Allocator) void {
    const value = utils.resolve_format(alloc, "%t  %p", timer, formatStr) catch {
        return;
    };
    defer value.deinit();

    const out = std.io.getStdOut().writer();
    out.print("{s}\n", .{value.items}) catch {};
}

pub fn timerLoop(timer: *PomodoroTimer) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const alloc = gpa.allocator();

    while (true) {
        std.time.sleep(std.time.ns_per_s);
        if (timer.seconds != 0 and !timer.paused) {
            on_tick(timer, alloc);
        }
        try timer.tick(on_cycle);
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
    var print_ok = true;
    var break_loop = false;
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
            on_tick(timer, alloc);
        },
        .seek_back => {
            timer.seek_back(5);
            on_tick(timer, alloc);
        },
        .quit => {
            break_loop = true;
        },
        .get_timer => {
            print_ok = false;
            const msg = try std.fmt.allocPrint(alloc, "{}\n{}\n{}\n{}\n", .{ timer.seconds, timer.session_count, @intFromBool(timer.paused), @intFromEnum(timer.mode) });
            defer alloc.free(msg);
            try writer.writeAll(msg);
            return break_loop;
        },
    }
    if (print_ok) {
        try writer.writeAll("OK\n");
    }
    return break_loop;
}
