// vim:fileencoding=utf-8:foldmethod=marker
// imports {{{
const std = @import("std");
const clap = @import("clap");
const utils = @import("utils.zig");
const known_folders = @import("known-folders");
// }}}
// globals {{{
const PomodoroTimer = @import("timer.zig").PomodoroTimer;
const PomodoroTimerConfig = @import("timer.zig").PomodoroTimerConfig;
const pvz = @import("pvz.zig");
const timer_loop = pvz.timer_loop;
const Request = pvz.Request;
const handle_request = pvz.handle_request;
pub const MAX_REQ_LEN = pvz.MAX_REQ_LEN;

const except = std.testing.expect;
const expectEqual = std.testing.expectEqual;
// }}}

const AppOptions = struct {
    flush: bool,
    new_line_on_quit: bool,
    run_socket: bool,
    format: [*]u8,
};

// TODO: clean the function :_(
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const alloc = gpa.allocator();
    const params = comptime clap.parseParamsComptime(
        \\-h, --help                        Display this help and exit
        \\-f, --format <str>                Format to show the timer
        \\-p, --port <u16>                  Port to connect to
        \\-P, --paused                      Pomodoro is paused by default
    );
    const config_dir = try known_folders.getPath(alloc, known_folders.KnownFolder.local_configuration) orelse ".";
    defer alloc.free(config_dir);

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = alloc,
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0)
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});

    var buff: [MAX_REQ_LEN]u8 = undefined;
    const port: u16 = res.args.port orelse 6660;

    const addr = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, port);
    var server = addr.listen(.{}) catch |err| {
        try expectEqual(error.AddressInUse, err);
        std.log.err("Port {} is already in use. Quitting...", .{port});
        std.process.exit(1);
    };
    std.log.info("Server is listening to port {d}", .{port});
    const format = res.args.format orelse "%m %t %p";

    defer server.deinit();

    var timer = PomodoroTimer{ .config = PomodoroTimerConfig{ .paused = res.args.paused != 0 } };
    timer.init();
    _ = try std.Thread.spawn(.{}, timer_loop, .{ alloc, &timer, format, config_dir });
    while (true) {
        var client = try server.accept();
        defer client.stream.close();
        const client_reader = client.stream.reader();
        const client_writer = client.stream.writer();
        const msg = client_reader.readUntilDelimiterOrEof(&buff, '\n') catch {
            try client_writer.writeAll("TOO LONG\n");
            std.log.err("The message recieved is too long.", .{});
            continue;
        } orelse continue;

        const request_int = try std.fmt.parseInt(u16, msg, 10);
        if (std.meta.intToEnum(Request, request_int)) |request| {
            std.log.info("Message recieved: \"{s}\"", .{@tagName(request)});
            if (try handle_request(request, &timer, &client_writer, format, config_dir)) break;
        } else |err| {
            std.log.info("Message ignored \"{}\"", .{std.zig.fmtEscapes(msg)});
            std.log.debug("Request parse error: {}", .{err});
            const response = try std.fmt.allocPrint(alloc, "Invalid request number {}\n", .{request_int});
            defer alloc.free(response);
            try client_writer.writeAll(response);
        }
    }
}
