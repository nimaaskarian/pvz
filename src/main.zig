const std = @import("std");
const known_folders = @import("known-folders");
const PomodoroTimer = @import("timer.zig").PomodoroTimer;
const PomodoroTimerConfig = @import("timer.zig").PomodoroTimerConfig;
const pvz = @import("pvz.zig");
const getServer = pvz.getServer;
const timerLoop = pvz.timerLoop;
const Request = pvz.Request;
const handleRequest = pvz.handleRequest;
pub const MAX_REQ_LEN = pvz.MAX_REQ_LEN;

const except = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const AppOptions = struct {
    flush: bool,
    new_line_on_quit: bool,
    run_socket: bool,
    format: [*]u8,
};

pub fn main() !void {
    var timer = PomodoroTimer{};
    timer.init();
    var gpa_alloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa_alloc.deinit() == .ok);
    const gpa = gpa_alloc.allocator();

    var buff: [MAX_REQ_LEN]u8 = undefined;
    var server = try getServer();
    _ = try std.Thread.spawn(.{}, timerLoop, .{&timer});
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
            try handleRequest(request, &timer);
            try client_writer.writeAll("OK\n");
        } else |err| {
            std.log.info("Message ignored \"{}\"", .{std.zig.fmtEscapes(msg)});
            std.log.debug("Request parse error: {}", .{err});
            const response = try std.fmt.allocPrint(gpa, "Invalid request number {}\n", .{request_int});
            defer gpa.free(response);
            try client_writer.writeAll(response);
        }
    }
}
