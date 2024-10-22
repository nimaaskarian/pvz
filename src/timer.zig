const std = @import("std");
const except = std.testing.expect;

const TimerMode = enum { Pomodoro, ShortBreak, LongBreak };

const DEFAULT_TIMER = PomodoroTimer{
    .paused = false,
    .seconds = 0,
    .pomodoro_seconds = 25 * std.time.s_per_min,
    .short_break_seconds = 5 * std.time.s_per_min,
    .long_break_seconds = 30 * std.time.s_per_min,
    .session_count = 4,
    .mode = TimerMode.Pomodoro,
};

pub const PomodoroTimer = struct {
    paused: bool,
    seconds: usize,
    mode: TimerMode,
    session_count: u16,
    long_break_seconds: u16,
    short_break_seconds: u16,
    pomodoro_seconds: u16,

    pub fn create() PomodoroTimer {
        var timer = DEFAULT_TIMER;
        timer.update_duration();
        return timer;
    }

    pub fn tick(self: *PomodoroTimer, comptime on_cycle: fn (timer: *PomodoroTimer) void) !void {
        std.time.sleep(std.time.ns_per_s);
        if (self.seconds == 0) {
            on_cycle(self);
            try self.cycle_mode();
            self.update_duration();
        } else {
            if (!self.paused) {
                self.seconds -= 1;
            }
        }
    }

    fn cycle_mode(self: *PomodoroTimer) !void {
        try except(self.session_count >= 0);
        switch (self.mode) {
            TimerMode.LongBreak => {
                std.log.debug("long break end. reseting", .{});
                self.* = DEFAULT_TIMER;
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
            return;
        }
    }

    fn update_duration(self: *PomodoroTimer) void {
        self.seconds = switch (self.mode) {
            TimerMode.Pomodoro => self.pomodoro_seconds,
            TimerMode.ShortBreak => self.short_break_seconds,
            TimerMode.LongBreak => self.long_break_seconds,
        };
    }

    pub fn format(
        self: PomodoroTimer,
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
