const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const io = std.io;

const month_lib = @import("month.zig");
const Month = month_lib.Month;
const CalendarMonth = month_lib.CalendarMonth;
const Week = @import("week.zig").Week;

pub const Weekday = enum {
    Monday = 1, Tuesday = 2, Wednesday = 3, Thursday = 4, Friday = 5, Saturday = 6, Sunday = 7
};

fn monthDaysApart(a: Month, b: Month) i32 {
    if (a.equals(b)) return 0;
    if (a.isBefore(b)) {
        var m = a;
        var result: i32 = 0;
        while (m.isBefore(b)) {
            result += m.numberOfDays();
            m = m.plusMonths(1);
        }
        return result;
    }
    return -monthDaysApart(b, a);
}

test "monthDaysApart" {
    testing.expectEqual(@as(i32, -30), monthDaysApart(Month.init(2020, 5), Month.init(2020, 4)));
    testing.expectEqual(@as(i32, 60), monthDaysApart(Month.init(2020, 1), Month.init(2020, 3)));
    testing.expectEqual(@as(i32, 59), monthDaysApart(Month.init(2100, 1), Month.init(2100, 3)));
}

pub const Date = struct {
    month: Month,
    day: i32,

    pub fn init(year: u16, month: i32, day: i32) Date {
        return Date.initFromMonth(Month.init(year, month), day);
    }

    pub fn initFromMonth(month: Month, day: i32) Date {
        var d = day;
        var m = month;
        const days_in_month = m.numberOfDays();
        while (d > m.numberOfDays()) {
            d -= m.numberOfDays();
            m = m.plusMonths(1);
        }
        while (d < 1) {
            m = m.minusMonths(1);
            d += m.numberOfDays();
        }

        return Date{
            .month = m,
            .day = d,
        };
    }

    pub fn plusDays(date: Date, days: i32) Date {
        return Date.initFromMonth(date.month, date.day + days);
    }

    pub fn minusDays(date: Date, days: i32) Date {
        return date.plusDays(-days);
    }

    pub fn daysLaterThan(date: Date, before: Date) i32 {
        var result = monthDaysApart(before.month, date.month);
        return result + date.day - before.day;
    }

    pub fn dayOfWeek(date: Date) Weekday {
        var weekday = @mod(3 + date.daysLaterThan(Date.init(2020, 1, 1)), 7);
        if (weekday == 0) weekday = 7;
        return @intToEnum(Weekday, @intCast(u3, weekday));
    }

    pub fn toWeek(date: Date) Week {
        return Week.fromDate(date);
    }

    pub fn isBefore(date: Date, other: Date) bool {
        return date.month.isBefore(other.month) or date.day < other.day;
    }

    pub fn isAfter(date: Date, other: Date) bool {
        return other.isBefore(date);
    }

    pub fn format(value: Date, comptime fmt: []const u8, options: std.fmt.FormatOptions, out_stream: var) !void {
        try out_stream.print("{}-{}-{}", .{ value.month.year, @enumToInt(value.month.month), value.day });
    }

    pub fn parse(string: []const u8) !Date {
        const err = error.InvalidDate;
        if (string.len != 10) return err;
        const year = std.fmt.parseInt(u16, string[0..4], 10) catch return err;
        if (string[4] != '-') return err;
        const month = std.fmt.parseInt(i32, string[5..7], 10) catch return err;
        if (string[7] != '-') return err;
        const day = std.fmt.parseInt(i32, string[8..10], 10) catch return err;
        return init(year, month, day);
    }

    /// Format keywords
    /// D - the day as one or two digits (1, 3, 15)
    /// DD - the day as two digits (01, 03, 15)
    /// Day - the day of the week (Monday, Friday)
    /// M - the month as one or two digits (1, 10)
    /// MM - the month as two digits (01, 10)
    /// Month - the month, written out (January, October)
    /// YY - the year as two digits (98, 20)
    /// YYYY - the year as four digits (1998, 2020)
    pub fn formatCustom(date: @This(), fmt: []const u8, out_stream: var) !void {
        var i: usize = 0;
        while (i < fmt.len) {
            var j = i;
            const char = fmt[i];
            if (char == 'D') {
                if (i + 1 < fmt.len and fmt[i + 1] == 'D') {
                    try out_stream.print("{d:0>2}", .{@intCast(u32, date.day)});
                    i += 2;
                    continue;
                }
                if (i + 2 < fmt.len and mem.eql(u8, fmt[i .. i + 3], "Day")) {
                    _ = try out_stream.write(@tagName(date.dayOfWeek()));
                    i += 3;
                    continue;
                }

                try out_stream.print("{d}", .{date.day});
                i += 1;
                continue;
            }
            if (char == 'M') {
                if (i + 1 < fmt.len and fmt[i + 1] == 'M') {
                    try out_stream.print("{d:0>2}", .{@enumToInt(date.month.month)});
                    i += 2;
                    continue;
                }
                if (i + 4 < fmt.len and mem.eql(u8, fmt[i .. i + 5], "Month")) {
                    _ = try out_stream.write(@tagName(date.month.month));
                    i += 5;
                    continue;
                }

                try out_stream.print("{d}", .{@enumToInt(date.month.month)});
                i += 1;
                continue;
            }
            if (char == 'Y') {
                if (i + 3 < fmt.len and mem.eql(u8, fmt[i .. i + 4], "YYYY")) {
                    try out_stream.print("{d:0>4}", .{date.month.year});
                    i += 4;
                    continue;
                }
                if (i + 1 < fmt.len and fmt[i + 1] == 'Y') {
                    const last_two_digits = date.month.year - @divTrunc(date.month.year, 100) * 100;
                    try out_stream.print("{d:0>2}", .{last_two_digits});
                    i += 2;
                    continue;
                }
            }
            try out_stream.writeByte(char);
            i += 1;
        }
    }

    pub fn parseCustom(fmt: []const u8, string: []const u8) !Date {
        var year: ?u16 = null;
        var month: ?i32 = null;
        var day: ?i32 = null;
        const peek = &io.peekStream(1, io.fixedBufferStream(string).inStream());
        const stream = &peek.inStream();
        for (fmt) |c, i| {
            switch (c) {
                'D' => {
                    if (day != null) return error.FormatHasTooManyDays;
                    day = 0;
                    var read: usize = 0;
                    while (read < 2) : (read += 1) {
                        const byte = stream.readByte() catch |err| {
                            switch (err) {
                                error.EndOfStream => break,
                            }
                        };
                        switch (byte) {
                            '0'...'9' => {
                                day = day.? * 10 + @as(i32, byte - '0');
                            },
                            else => {
                                try peek.putBackByte(byte);
                            },
                        }
                    }
                    if (read == 0) return error.InvalidDay;
                },
                'M' => {
                    if (month != null) return error.FormatHasTooManyMonths;
                    month = 0;
                    var read: usize = 0;
                    while (read < 2) : (read += 1) {
                        const byte = stream.readByte() catch |err| {
                            switch (err) {
                                error.EndOfStream => break,
                            }
                        };
                        switch (byte) {
                            '0'...'9' => {
                                month = month.? * 10 + @as(i32, byte - '0');
                            },
                            else => {
                                try peek.putBackByte(byte);
                            },
                        }
                    }
                    if (read == 0) return error.InvalidMonth;
                },
                'Y' => {
                    if (year != null) return error.FormatHsTooManyYears;
                    year = 0;
                    var read: usize = 0;
                    while (read < 4) : (read += 1) {
                        const byte = stream.readByte() catch |err| {
                            switch (err) {
                                error.EndOfStream => break,
                            }
                        };
                        switch (byte) {
                            '0'...'9' => {
                                year = year.? * 10 + @as(u16, byte - '0');
                            },
                            else => {
                                try peek.putBackByte(byte);
                            },
                        }
                    }
                    if (read == 0) return error.InvalidYear;
                },
                else => {
                    if ((try stream.readByte()) != c) return error.FailedToMatchLiteral;
                },
            }
        }
        if (year) |y| {
            if (month) |m| {
                if (day) |d| {
                    return init(y, m, d);
                } else return error.FormatHasNoDate;
            } else return error.FormatHasNoMonth;
        } else return error.FormatHasNoYear;
    }
};

test "can create day" {
    testing.expectEqual(Date{
        .month = .{ .year = 2020, .month = .March },
        .day = 5,
    }, Date.init(2020, 3, 5));
}

test "days wrap around months" {
    testing.expectEqual(Date.init(2020, 5, 4), Date.init(2020, 4, 24).plusDays(10));
    testing.expectEqual(Date.init(2019, 12, 23), Date.init(2020, 2, 10).minusDays(49));
    testing.expectEqual(Date.init(2020, 2, 24), Date.init(2020, 3, 1).minusDays(6));
}

test "daysLaterThan" {
    testing.expectEqual(@as(i32, 25), Date.init(2020, 2, 28).daysLaterThan(Date.init(2020, 2, 3)));
    testing.expectEqual(@as(i32, -50), Date.init(2020, 1, 15).daysLaterThan(Date.init(2020, 3, 5)));
}

test "dayOfWeek" {
    testing.expectEqual(Weekday.Friday, Date.init(2020, 1, 3).dayOfWeek());
    testing.expectEqual(Weekday.Tuesday, Date.init(2020, 8, 18).dayOfWeek());
    testing.expectEqual(Weekday.Friday, Date.init(2023, 8, 18).dayOfWeek());
}

test "toWeek" {
    testing.expectEqual(Date.init(2020, 3, 2), Date.init(2020, 3, 8).toWeek().monday);
}

test "formatCustom" {
    var buffer = [_]u8{0} ** 19;
    {
        var stream = std.io.fixedBufferStream(buffer[0..]);
        const out_stream = &stream.outStream();
        try Date.init(2020, 6, 1).formatCustom("Day, Month D, 'YY", out_stream);
        testing.expectEqualSlices(u8, "Monday, June 1, '20", stream.buffer);
    }
    {
        var stream = std.io.fixedBufferStream(buffer[0..10]);
        const out_stream = &stream.outStream();
        try Date.init(2020, 6, 1).formatCustom("YYYY-MM-DD", out_stream);
        testing.expectEqualSlices(u8, "2020-06-01", stream.buffer);
    }
}
test "parse" {
    testing.expectEqual(Date.init(2020, 6, 1), try Date.parse("2020-06-01"));
}
test "parseCustom" {
    testing.expectEqual(Date.init(2020, 6, 1), try Date.parseCustom("Y/M/D", "2020/6/1"));
    testing.expectEqual(Date.init(2020, 3, 17), try Date.parseCustom("Y-M-D", "2020-03-17 19:23:18 PDT"));
    testing.expectEqual(Date.init(2020, 5, 8), try Date.parseCustom("M/D/Y", "05/08/2020"));
}
