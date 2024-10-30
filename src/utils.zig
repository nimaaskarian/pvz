const std = @import("std");
const mem = std.mem;

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

pub fn intLen(in: anytype) usize {
    var n = in;
    var count = 0;
    while (n != 0) : (count += 1) {
        n /= 10;
    }
    return count;
}
