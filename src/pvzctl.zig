const std = @import("std");
const pvz = @import("pvz.zig");
const clap = @import("clap");
const getServer = pvz.getServer;
const timerLoop = pvz.timerLoop;
pub const Request = pvz.Request;
pub const MAX_REQ_LEN = pvz.MAX_REQ_LEN;

// TODO: clean the damn function
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const params = comptime clap.parseParamsComptime(
        \\-r, --request <REQUEST>...        Request to be sent
        \\-h, --help                        Display this help and exit.
        \\-p, --port <u16>                  Port to connect to
    );
    const parsers = comptime .{ .REQUEST = clap.parsers.enumeration(Request), .u16 = clap.parsers.int(u16, 10) };
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
        .allocator = gpa.allocator(),
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0)
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    std.debug.print("{any}\n", .{res.args.request});
    const addr = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, res.args.port orelse 6660);
    var buff: [MAX_REQ_LEN]u8 = undefined;
    for (res.args.request) |request| {
        const stream = try std.net.tcpConnectToAddress(addr);
        const msg = try std.fmt.bufPrint(&buff, "{}\n", .{@intFromEnum(request)});
        _ = try stream.write(msg);
    }
}
