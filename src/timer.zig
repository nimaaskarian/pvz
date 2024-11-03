// vim:fileencoding=utf-8:foldmethod=marker
// imports{{{
const std = @import("std");
const mem = std.mem;
// }}}

pub const TimerMode = enum { Pomodoro, ShortBreak, LongBreak };

pub const PomodoroTimerConfig = struct {
    session_count: u16 = 4,
    long_break_seconds: u16 = 30 * std.time.s_per_min,
    short_break_seconds: u16 = 5 * std.time.s_per_min,
    pomodoro_seconds: u16 = 25 * std.time.s_per_min,
    paused: bool = false,
};

pub const PomodoroTimer = struct {
    paused: bool = false,
    seconds: usize = 0,
    mode: TimerMode = TimerMode.Pomodoro,
    config: PomodoroTimerConfig = .{},
    session_count: usize = 0,

    pub fn init(self: *PomodoroTimer) void {
        self.session_count = self.config.session_count;
        self.paused = self.config.paused;
        self.mode = TimerMode.Pomodoro;
        self.update_duration();
    }

    pub fn seek(self: *PomodoroTimer, seek_amount: usize) void {
        self.seconds += seek_amount;
    }

    pub fn seek_back(self: *PomodoroTimer, seek_amount: usize) void {
        if (seek_amount > self.seconds) {
            self.seconds = 0;
        } else {
            self.seconds -= seek_amount;
        }
    }

    pub fn tick(
        self: *PomodoroTimer,
    ) !void {
        std.time.sleep(std.time.ns_per_s);
        if (self.seconds == 0) {
            try self.cycle_mode();
        } else {
            if (!self.paused) {
                self.seconds -= 1;
            }
        }
    }

    pub fn cycle_mode(self: *PomodoroTimer) !void {
        switch (self.mode) {
            TimerMode.LongBreak => {
                std.log.debug("long break end. reseting", .{});
                self.init();
            },
            TimerMode.ShortBreak => {
                std.log.debug("cycle to pomodoro", .{});
                self.mode = TimerMode.Pomodoro;
            },
            TimerMode.Pomodoro => {
                std.log.debug("cycle to short break", .{});
                self.mode = TimerMode.ShortBreak;
                self.session_count -= 1;
            },
        }
        if (self.session_count <= 0) {
            std.log.debug("count=0 -> cycle to long break", .{});
            self.mode = TimerMode.LongBreak;
        }
        self.update_duration();
    }

    pub fn update_duration(self: *PomodoroTimer) void {
        self.seconds = switch (self.mode) {
            TimerMode.Pomodoro => self.config.pomodoro_seconds,
            TimerMode.ShortBreak => self.config.short_break_seconds,
            TimerMode.LongBreak => self.config.long_break_seconds,
        };
    }

    pub fn format(
        self: *const PomodoroTimer,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        var seconds = self.seconds % std.time.s_per_hour;
        const hours = self.seconds / std.time.s_per_hour;
        const minutes = seconds / std.time.s_per_min;
        seconds = seconds % std.time.s_per_min;
        if (hours == 0) {
            try writer.print("{:0>2}:{:0>2}", .{ minutes, seconds });
        } else {
            try writer.print("{}:{:0>2}:{:0>2}", .{ hours, minutes, seconds });
        }
    }
};

fn alloc_print_catch(alloc: mem.Allocator, comptime format: []const u8, args: anytype) ?[]u8 {
    return std.fmt.allocPrint(alloc, format, args) catch {
        return null;
    };
}

pub fn format_str(alloc: std.mem.Allocator, args: anytype, ch: u8) ?[]u8 {
    return switch (ch) {
        't' => alloc_print_catch(alloc, "{s}", .{args}),
        'p' => alloc_print_catch(alloc, "{}", .{args.session_count}),
        'm' => alloc_print_catch(alloc, "{s}", .{@tagName(args.mode)}),
        's' => alloc_print_catch(alloc, "{}", .{args.seconds}),
        else => null,
    };
}
