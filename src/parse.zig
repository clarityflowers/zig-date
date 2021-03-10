const std = @import("std");

pub fn ParseResult(comptime Type: type) type {
    return struct {
        data: Type,
        new_pos: usize,
    };
}
pub fn parseResult(data: anytype, new_pos: usize) ParseResult(@TypeOf(data)) {
    return .{
        .data = data,
        .new_pos = new_pos,
    };
}

pub fn matchLiteral(str: []const u8, index: usize, literal: []const u8) ?usize {
    if (str.len - index >= literal.len and std.mem.eql(u8, str[index .. index + literal.len], literal)) {
        return index + literal.len;
    }
    return null;
}
