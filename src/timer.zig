const std = @import("std");
const except = std.testing.expect;

const TimerMode = enum { Pomodoro, ShortBreak, LongBreak };

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

    pub fn tick(
        self: *PomodoroTimer,
        comptime on_tick: fn (timer: *PomodoroTimer) void,
        comptime on_cycle: fn (timer: *PomodoroTimer) void,
    ) !void {
        if (self.seconds == 0) {
            on_cycle(self);
            try self.cycle_mode();
        } else {
            if (!self.paused) {
                on_tick(self);
                self.seconds -= 1;
            }
            std.time.sleep(std.time.ns_per_s);
        }
    }

    pub fn cycle_mode(self: *PomodoroTimer) !void {
        try except(self.session_count >= 0);
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
        const tagName = @tagName(self.mode);
        if (hours == 0) {
            try writer.print("{:0>2}:{:0>2} {s}", .{ minutes, seconds, tagName });
        } else {
            try writer.print("{}:{:0>2}:{:0>2} {s}", .{ hours, minutes, seconds, tagName });
        }
    }
};
