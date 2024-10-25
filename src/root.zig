const std = @import("std");
const testing = std.testing;
pub const PomodoroTimer = @import("timer.zig").PomodoroTimer;
const pvz = @import("pvz.zig");
pub const Request = pvz.Request;

test "cycle to short break" {
    var timer = PomodoroTimer.create_with_config(.{ .pomodoro_seconds = 1 });
    for (0..1) |_| {
        try timer.tick(null);
    }
    std.time.sleep(std.time.ns_per_s * 20);
    try testing.expectEqual(0, timer.seconds);
}
