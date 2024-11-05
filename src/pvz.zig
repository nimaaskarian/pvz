// vim:fileencoding=utf-8:foldmethod=marker
// imports {{{
const std = @import("std");
const utils = @import("utils.zig");
// }}}
// globals {{{
const mem = std.mem;
const except = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const pomodoro_timer = @import("timer.zig");
const PomodoroTimer = pomodoro_timer.PomodoroTimer;
pub const max_req_len = utils.int_len(std.meta.fields(Request).len) + 1;
// }}}

pub fn on_start(alloc: mem.Allocator, timer: *const PomodoroTimer, config_dir: []const u8) !void {
    std.log.debug("on_start callback! timer.mode: {}", .{timer.mode});
    const name = switch (timer.mode) {
        .Pomodoro => "on-pomodoro-start.sh",
        .ShortBreak => "on-short-break-start.sh",
        .LongBreak => "on-long-break-start.sh",
    };
    try run_script(alloc, config_dir, name);
}

fn on_end(alloc: mem.Allocator, timer: *PomodoroTimer, config_dir: []const u8) !void {
    std.log.debug("on_end callback! timer.mode: {}", .{timer.mode});
    const name = switch (timer.mode) {
        .Pomodoro => "on-pomodoro-end.sh",
        .ShortBreak => "on-short-break-end.sh",
        .LongBreak => "on-long-break-end.sh",
    };
    if (timer.mode == .LongBreak) {
        try init_timer(alloc, timer, config_dir);
    }
    try run_script(alloc, config_dir, name);
}

fn run_script(alloc: mem.Allocator, config_dir: []const u8, name: []const u8) !void {
    const pvz_dir_base = comptime std.fmt.comptimePrint("{c}{s}{c}", .{ std.fs.path.sep, "pvz", std.fs.path.sep });
    const script_file = try std.fmt.allocPrint(alloc, "{s}{s}{s}", .{ config_dir, pvz_dir_base, name });
    defer alloc.free(script_file);

    const argv = [_][]const u8{script_file};
    var proc = std.process.Child.init(&argv, alloc);
    try proc.spawn();
}

fn on_tick(timer: *PomodoroTimer, alloc: mem.Allocator, format: []const u8) void {
    const value = utils.resolve_format(alloc, format, timer, pomodoro_timer.format_str) catch {
        return;
    };
    defer value.deinit();

    const out = std.io.getStdOut().writer();
    out.print("{s}\n", .{value.items}) catch {};
}

fn init_timer(alloc: mem.Allocator, timer: *PomodoroTimer, config_dir: []const u8) !void {
    try on_start(alloc, timer, config_dir);
    if (timer.paused) try run_script(alloc, config_dir, "on-pause.sh");
}

pub fn timer_loop(alloc: mem.Allocator, timer: *PomodoroTimer, format: []const u8, config_dir: []const u8) !void {
    try init_timer(alloc, timer, config_dir);
    while (true) {
        if (timer.seconds != 0 and !timer.paused) {
            on_tick(timer, alloc, format);
        }
        const is_last_sec = timer.seconds == 0;
        if (is_last_sec) {
            try on_end(alloc, timer, config_dir);
        }
        try timer.tick();
        if (is_last_sec) {
            try on_start(alloc, timer, config_dir);
        }
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
    add_session,
    sub_session,
};

pub fn handle_request(alloc: mem.Allocator, req: Request, timer: *PomodoroTimer, writer: anytype, format: []const u8, config_dir: []const u8) !bool {
    switch (req) {
        .toggle => {
            if (timer.paused) {
                try run_script(alloc, config_dir, "on-unpause.sh");
            } else {
                try run_script(alloc, config_dir, "on-pause.sh");
            }
            timer.paused = !timer.paused;
        },
        .skip => {
            try timer.cycle_mode();
            try on_start(alloc, timer, config_dir);
        },
        .current_reset => timer.update_duration(),
        .pause => {
            timer.paused = true;
            try run_script(alloc, config_dir, "on-pause.sh");
        },
        .unpause => {
            timer.paused = false;
            try run_script(alloc, config_dir, "on-unpause.sh");
        },
        .reset => {
            timer.init();
            try init_timer(alloc, timer, config_dir);
        },
        .seek => {
            timer.seek(5);
            on_tick(timer, alloc, format);
        },
        .seek_back => {
            timer.seek_back(5);
            on_tick(timer, alloc, format);
        },
        .quit => {
            try writer.writeAll("OK\n");
            return true;
        },
        .get_timer => {
            const msg = try std.fmt.allocPrint(alloc, "{}\n{}\n{}\n{}\n", .{ timer.seconds, timer.session_count, @intFromBool(timer.paused), @intFromEnum(timer.mode) });
            defer alloc.free(msg);
            try writer.writeAll(msg);
        },
        .add_session => {
            timer.session_count += 1;
        },
        .sub_session => {
            if (timer.session_count != 0) {
                timer.session_count -= 1;
            }
        },
    }
    try writer.writeAll("OK\n");
    return false;
}
