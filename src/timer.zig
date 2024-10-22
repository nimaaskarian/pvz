const std = @import("std");
const except = std.testing.expect;

const TimerState = enum { Pomodoro, ShortBreak, LongBreak };

const default_timer = Timer{
    .paused = false,
    .seconds = 0,
    .pomodoro_minutes = 25,
    .short_break_minutes = 5,
    .long_break_minutes = 30,
    .pomodoro_count = 25,
    .state = TimerState.Pomodoro,
};

pub const Timer = struct {
    paused: bool,
    seconds: usize,
    state: TimerState,
    pomodoro_count: u16,
    long_break_minutes: u16,
    short_break_minutes: u16,
    pomodoro_minutes: u16,

    pub fn create() Timer {
        var timer = default_timer;
        timer.set_seconds_based_on_type();
        return timer;
    }

    pub fn sleep_reduce_second(self: *Timer, comptime on_cycle: fn (timer: *Timer) void) !void {
        std.time.sleep(@intCast(std.time.ns_per_s));
        if (self.seconds == 0) {
            on_cycle(self);
            try self.cycle_type();
            self.set_seconds_based_on_type();
        } else {
            if (!self.paused) {
                self.seconds -= 1;
            }
        }
    }

    pub fn cycle_type(self: *Timer) !void {
        try except(self.pomodoro_count >= 0);
        switch (self.state) {
            TimerState.LongBreak => {
                std.log.debug("long break end. reseting", .{});
                self.* = default_timer;
            },
            TimerState.ShortBreak => {
                std.log.debug("cycle to pomodoro", .{});
                self.state = TimerState.Pomodoro;
            },
            TimerState.Pomodoro => {
                std.log.debug("cycle to short break", .{});
                self.state = TimerState.ShortBreak;
                self.pomodoro_count -= 1;
            },
        }
        if (self.pomodoro_count <= 0) {
            std.log.debug("count=0 -> cycle to long break", .{});
            self.state = TimerState.LongBreak;
            return;
        }
    }

    fn set_seconds_based_on_type(self: *Timer) void {
        const minutes = switch (self.state) {
            TimerState.Pomodoro => self.pomodoro_minutes,
            TimerState.ShortBreak => self.short_break_minutes,
            TimerState.LongBreak => self.long_break_minutes,
        };
        self.seconds = minutes * std.time.s_per_min;
    }

    pub fn format(
        self: Timer,
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
