const std = @import("std");
const testing = std.testing;
pub const Month = @import("month.zig").Month;
pub const Week = @import("week.zig").Week;
pub const Date = @import("date.zig").Date;

comptime {
    if (std.builtin.is_test) {
        _ = @import("date.zig");
        _ = @import("week.zig");
        _ = @import("month.zig");
    }
}
