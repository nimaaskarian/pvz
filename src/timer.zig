const std = @import("std");
const except = std.testing.expect;

const TimerMode = enum { Pomodoro, ShortBreak, LongBreak };

const DEFAULT_TIMER = PomodoroTimer{
    .seconds = 0,
    .session_count = 0,
    .paused = false,
    .mode = TimerMode.Pomodoro,
    .config = PomodoroTimerConfig{
        .pomodoro_seconds = 25 * std.time.s_per_min,
        .short_break_seconds = 5 * std.time.s_per_min,
        .long_break_seconds = 30 * std.time.s_per_min,
        .paused = false,
        .session_count = 4,
    },
};

pub const PomodoroTimerConfig = struct {
    session_count: u16,
    long_break_seconds: u16,
    short_break_seconds: u16,
    pomodoro_seconds: u16,
    paused: bool,
};

pub const PomodoroTimer = struct {
    paused: bool,
    seconds: usize,
    mode: TimerMode,
    config: PomodoroTimerConfig,
    session_count: usize,

    pub fn create() PomodoroTimer {
        var timer = DEFAULT_TIMER;
        timer.reset();
        return timer;
    }

    pub fn create_with_config(config: PomodoroTimerConfig) PomodoroTimer {
        var timer = DEFAULT_TIMER;
        timer.config = config;
        timer.reset();
        return timer;
    }

    fn reset(self: *PomodoroTimer) void {
        self.session_count = self.config.session_count;
        self.paused = self.config.paused;
        self.update_duration();
    }

    pub fn totalReset(self: *PomodoroTimer) void {
        const config = self.config;
        self.* = DEFAULT_TIMER;
        self.config = config;
        self.reset();
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
                self.mode = TimerMode.Pomodoro;
                self.reset();
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
