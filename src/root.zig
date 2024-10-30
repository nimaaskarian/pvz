// vim:fileencoding=utf-8:foldmethod=marker
// imports {{{
const std = @import("std");
const pvz = @import("pvz.zig");
const pomodoro_timer = @import("timer.zig");
const testing = std.testing;
// }}}
// globals {{{
pub const PomodoroTimer = pomodoro_timer.PomodoroTimer;
pub const PomodoroTimerConfig = pomodoro_timer.PomodoroTimerConfig;
pub const TimerMode = pomodoro_timer.TimerMode;
pub const Request = pvz.Request;
const POMODORO_SECONDS = 42000;
// }}}

var timer = PomodoroTimer{ .config = PomodoroTimerConfig{ .pomodoro_seconds = POMODORO_SECONDS } };
test "timer init" {
    timer.init();
    try testing.expectEqual(TimerMode.Pomodoro, timer.mode);
    try testing.expectEqual(POMODORO_SECONDS, timer.seconds);
}

test "timer tick" {
    timer.init();
    for (0..POMODORO_SECONDS) |i| {
        try testing.expectEqual(POMODORO_SECONDS - i, timer.seconds);
        try timer.tick();
    }
    try testing.expectEqual(0, timer.seconds);
    try timer.tick();
    try testing.expectEqual(TimerMode.ShortBreak, timer.mode);
}
