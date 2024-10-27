const std = @import("std");
const pvz = @import("pvz.zig");
const utils = @import("utils.zig");
const clap = @import("clap");
const getServer = pvz.getServer;
pub const Request = pvz.Request;
pub const MAX_REQ_LEN = pvz.MAX_REQ_LEN;
const pomodoro_timer = @import("timer.zig");
const PomodoroTimer = pomodoro_timer.PomodoroTimer;
const formatStr = pomodoro_timer.formatStr;
const parsers = .{ .REQUEST = clap.parsers.enumeration(Request), .u16 = clap.parsers.int(u16, 0), .str = clap.parsers.string };

// TODO: clean the damn function
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();
    const params = comptime clap.parseParamsComptime(
        \\-r, --request <REQUEST>...        Request to be sent
        \\-f, --format <str>                Format to show the timer
        \\-h, --help                        Display this help and exit.
        \\-p, --port <u16>                  Port to connect to
    );
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
        .allocator = alloc,
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0)
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});

    const addr = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, res.args.port orelse 6660);
    var buff: [MAX_REQ_LEN]u8 = undefined;
    for (res.args.request) |request| {
        const stream = try std.net.tcpConnectToAddress(addr);
        defer stream.close();
        const msg = try std.fmt.bufPrint(&buff, "{}\n", .{@intFromEnum(request)});
        _ = try stream.write(msg);
        if (request == .get_timer) {
            var timer = PomodoroTimer{};
            const reader = stream.reader();
            var index: usize = 0;
            while (try reader.readUntilDelimiterOrEofAlloc(alloc, '\n', 65536)) |line| : (index += 1) {
                defer alloc.free(line);
                switch (index) {
                    0 => timer.seconds = try std.fmt.parseInt(usize, line, 10),
                    1 => timer.session_count = try std.fmt.parseInt(usize, line, 10),
                    2 => timer.paused = try std.fmt.parseInt(u1, line, 10) == 1,
                    3 => {
                        const mode_value = try std.fmt.parseInt(usize, line, 10);
                        timer.mode = @enumFromInt(mode_value);
                    },
                    else => {},
                }
            }
            const format = res.args.format orelse "%t %p";
            const timer_str = try utils.resolve_format(alloc, format, timer, formatStr);
            defer timer_str.deinit();
            const out = std.io.getStdOut().writer();
            out.print("{s}\n", .{timer_str.items}) catch {};
        }
    }
}
