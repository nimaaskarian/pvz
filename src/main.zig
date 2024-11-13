// vim:fileencoding=utf-8:foldmethod=marker
// imports {{{
const std = @import("std");
const clap = @import("clap");
const utils = @import("utils.zig");
const known_folders = @import("known-folders");
const pvz = @import("pvz.zig");
// }}}
// globals {{{
const log = std.log;
const PomodoroTimer = @import("timer.zig").PomodoroTimer;
const PomodoroTimerConfig = @import("timer.zig").PomodoroTimerConfig;

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
    var gpa = comptime std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const alloc = gpa.allocator();
    const params = comptime clap.parseParamsComptime(
        \\-h, --help                        Display this help and exit
        \\-f, --format <str>                Format to show the timer
        \\-p, --port <u16>                  Port to connect to
        \\-P, --unpaused                    Pomodoro is unpaused by default
        \\<str>                             IP to listen to
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

    var buff: [pvz.max_req_len]u8 = undefined;
    const port: u16 = res.args.port orelse 6660;

    const addr = utils.resolve_ip(utils.get([]const u8, res.positionals, 0), port) catch {
        std.log.err("IP is wrong", .{});
        return;
    };
    var server = addr.listen(.{}) catch |err| {
        try expectEqual(error.AddressInUse, err);
        log.err("Port {} is already in use. Quitting...", .{port});
        std.process.exit(1);
    };
    defer server.deinit();
    defer std.debug.print("SERVER DEINIT\n", .{});
    std.log.info("Server is listening to port {d}", .{port});

    var timer = PomodoroTimer{ .config = PomodoroTimerConfig{ .paused = res.args.unpaused == 0 } };
    timer.init();
    const format = res.args.format orelse "%m %t %p";

    _ = try std.Thread.spawn(.{}, pvz.timer_loop, .{ alloc, &timer, format, config_dir });
    var should_break = false;
    while (!should_break) {
        var client = try server.accept();
        defer client.stream.close();
        defer std.debug.print("CLIENT STREAM CLOSED\n", .{});
        const client_writer = client.stream.writer();
        const msg = client.stream.reader().readUntilDelimiterOrEof(&buff, '\n') catch {
            try client_writer.writeAll("TOO LONG\n");
            log.err("The message recieved is too long.", .{});
            continue;
        } orelse continue;

        const request_int = try std.fmt.parseInt(u16, msg, 10);
        if (std.meta.intToEnum(pvz.Request, request_int)) |request| {
            log.info("Message recieved: \"{s}\"", .{@tagName(request)});
            should_break = try pvz.handle_request(alloc, request, &timer, &client_writer, format, config_dir);
        } else |err| {
            log.info("Message ignored \"{}\"", .{std.zig.fmtEscapes(msg)});
            log.debug("Request parse error: {}", .{err});
            const response = try std.fmt.allocPrint(alloc, "Invalid request number {}\n", .{request_int});
            defer alloc.free(response);
            try client_writer.writeAll(response);
        }
    }
}
