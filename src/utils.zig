// vim:fileencoding=utf-8:foldmethod=marker
// imports{{{
const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const net = std.net;
// }}}

pub fn resolve_format(alloc: mem.Allocator, format: []const u8, args: anytype, comptime handler: fn (alloc: mem.Allocator, args: anytype, ch: u8) ?[]u8) !std.ArrayList(u8) {
    var buff = std.ArrayList(u8).init(alloc);
    var index: usize = 0;
    while (index < format.len) : (index += 1) {
        const ch = format[index];
        if (ch == '%') {
            if (index < format.len and format[index + 1] != '%') {
                if (handler(alloc, args, format[index + 1])) |formatted_string| {
                    defer alloc.free(formatted_string);
                    try buff.appendSlice(formatted_string);
                    index += 1;
                }
            } else {
                try buff.append('%');
                index += 1;
            }
        } else {
            try buff.append(ch);
        }
    }
    return buff;
}

pub fn int_len(in: anytype) usize {
    var n = in;
    var count = 0;
    while (n != 0) : (count += 1) {
        n /= 10;
    }
    return count;
}

const parseFunction = if (builtin.target.os.tag == .windows) net.Address.parseIp else net.Address.resolveIp;
pub fn resolve_ip(may_ip: ?[]const u8, port: u16) !net.Address {
    if (may_ip) |ip| {
        return parseFunction(ip, port);
    }
    return net.Address.initIp4(.{ 127, 0, 0, 1 }, port);
}

pub fn get(comptime T: type, arr: []const T, index: comptime_int) ?T {
    if (index < arr.len) {
        return arr[index];
    }
    return null;
}
