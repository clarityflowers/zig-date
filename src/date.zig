const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const io = std.io;

const month_lib = @import("month.zig");
const Month = month_lib.Month;
const CalendarMonth = month_lib.CalendarMonth;
const Week = @import("week.zig").Week;
usingnamespace @import("parse.zig");

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

    pub fn equals(self: @This(), other: @This()) bool {
        return self.day == other.day and self.month.equals(other.month);
    }

    pub fn toWeek(date: Date) Week {
        return Week.fromDate(date);
    }

    pub fn isBefore(date: Date, other: Date) bool {
        if (date.month.equals(other.month)) return date.day < other.day;
        return date.month.isBefore(other.month);
    }

    pub fn isAfter(date: Date, other: Date) bool {
        return other.isBefore(date);
    }

    pub fn parse(string: []const u8) !Date {
        return try parseStringComptimeFmt("Y-M-D", string);
    }

    /// The format keywords are listed below. Any other characters are reproduced literally.
    /// D - the day as one or two digits (1, 3, 15)
    /// DD - the day as two digits (01, 03, 15)
    /// Weekday - the day of the week (Monday, Friday)
    /// Day - the day of the week, short (Mon, Fri)
    /// M - the month as one or two digits (1, 10)
    /// MM - the month as two digits (01, 10)
    /// Month - the month, written out (January, October)
    /// Mon - the month, short (Jan, Oct)
    /// YY - the year as two digits (98, 20)
    /// YYYY - the year as four digits (1998, 2020)
    pub fn format(
        value: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        if (fmt.len == 0) return writer.print("{YYYY-MM-DD}", .{value});
        comptime const tokens = comptime blk: {
            var stream = DateFormatTokenStream{ .fmt = fmt };
            var tokens: []const DateFormatToken = &[0]DateFormatToken{};
            inline while (stream.next()) |token| {
                tokens = tokens ++ &[1]DateFormatToken{token};
            }
            break :blk tokens;
        };
        inline for (tokens) |token| {
            try token.print(value, writer);
        }
    }

    pub fn formatRuntime(
        value: @This(),
        fmt: []const u8,
        writer: anytype,
    ) !void {
        if (fmt.len == 0) return writer.print("{YYYY-MM-DD}", .{value});
        var stream = DateFormatTokenStream{ .fmt = fmt };
        while (stream.next()) |token| {
            try token.print(value, writer);
        }
    }

    pub fn toString(self: @This()) [10:0]u8 {
        var buffer: [10:0]u8 = undefined;
        const writer = std.io.fixedBufferStream(@as([]u8, &buffer)).writer();
        writer.print("{}", .{self}) catch unreachable;
        return buffer;
    }

    pub fn parseFmt(fmt: []const u8, reader: anytype) !Date {
        return parseDateFmt(fmt, .date, reader);
    }

    pub fn parseStringFmt(fmt: []const u8, str: []const u8) !Date {
        var reader = io.fixedBufferStream(str).reader();
        return parseFmt(fmt, reader);
    }

    pub fn parseComptimeFmt(comptime fmt: []const u8, reader: anytype) !Date {
        return parseDateComptimeFmt(fmt, .date, reader);
    }

    pub fn parseStringComptimeFmt(comptime fmt: []const u8, str: []const u8) !Date {
        var reader = io.fixedBufferStream(str).reader();
        return parseComptimeFmt(fmt, reader);
    }
};

const DateFormatToken = union(enum) {
    day_1digit,
    day_2digit,
    day_of_week_short,
    day_of_week_long,
    month: month_lib.FormatToken,

    fn print(self: @This(), value: Date, writer: anytype) !void {
        switch (self) {
            .day_1digit => try writer.print("{d}", .{value.day}),
            .day_2digit => {
                try writer.print("{d:0>2}", .{@intCast(u32, value.day)});
            },
            .day_of_week_short => {
                try writer.writeAll(@tagName(value.dayOfWeek())[0..3]);
            },
            .day_of_week_long => {
                try writer.writeAll(@tagName(value.dayOfWeek()));
            },
            .month => |month| try month.print(value.month, writer),
        }
    }
};

const DateFormatTokenStream = struct {
    fmt: []const u8,
    index: usize = 0,

    fn next(self: *@This()) ?DateFormatToken {
        if (self.index >= self.fmt.len) return null;
        if (month_lib.parseFormatToken(self.fmt, self.index)) |res| {
            self.index = res.new_pos;
            return DateFormatToken{ .month = res.data };
        } else if (matchLiteral(self.fmt, self.index, "DD")) |index| {
            self.index = index;
            return DateFormatToken.day_2digit;
        } else if (matchLiteral(self.fmt, self.index, "Day")) |index| {
            self.index = index;
            return DateFormatToken.day_of_week_short;
        } else if (matchLiteral(self.fmt, self.index, "Weekday")) |index| {
            self.index = index;
            return DateFormatToken.day_of_week_long;
        } else if (matchLiteral(self.fmt, self.index, "D")) |index| {
            self.index = index;
            return DateFormatToken.day_1digit;
        } else {
            defer self.index += 1;
            return DateFormatToken{
                .month = .{
                    .literal = self.fmt[self.index],
                },
            };
        }
    }
};

const ParseMode = enum {
    month, date
};

pub fn parseDateComptimeFmt(comptime fmt: []const u8, comptime mode: ParseMode, reader: anytype) !(switch (mode) {
    .month => Month,
    .date => Date,
}) {
    var year: u16 = undefined;
    var month: i32 = undefined;
    var day: i32 = undefined;

    comptime var has_year = false;
    comptime var has_month = false;
    comptime var has_day = false;

    var peek_stream = io.peekStream(1, reader);

    inline for (fmt) |c, i| {
        var match_literal = false;
        switch (c) {
            'D' => {
                if (mode == .month) {
                    match_literal = true;
                    continue;
                }
                if (has_day) @compileError("Parse format can only have one 'D'.");
                has_day = true;
                day = try parseIntUpToNDigits(i32, &peek_stream, 2);
            },
            'M' => {
                if (has_month) @compileError("Parse format can only have one 'M'.");
                has_month = true;
                month = try parseIntUpToNDigits(i32, &peek_stream, 2);
            },
            'Y' => {
                if (has_year) @compileError("Parse format can only have one 'Y'");
                year = try parseIntUpToNDigits(u16, &peek_stream, 4);
            },
            else => {
                match_literal = true;
            },
        }
        if (match_literal) {
            if ((try peek_stream.reader().readByte()) != c) return error.FailedToMatchLiteral;
        }
    }
    return switch (mode) {
        .month => Month.init(year, month),
        .date => Date.init(year, month, day),
    };
}

pub fn parseDateFmt(fmt: []const u8, comptime mode: ParseMode, reader: anytype) !(switch (mode) {
    .month => Month,
    .date => Date,
}) {
    var year: ?u16 = null;
    var month: ?i32 = null;
    var day: ?i32 = null;
    var peek_stream = io.peekStream(1, reader);
    for (fmt) |c, i| {
        var match_literal = false;
        switch (c) {
            'D' => {
                if (mode == .month) {
                    match_literal = true;
                    continue;
                }
                if (day != null) {
                    return error.FormatHasTooManyDays;
                }
                day = try parseIntUpToNDigits(i32, &peek_stream, 2);
            },
            'M' => {
                if (month != null) return error.FormatHasTooManyMonths;
                month = try parseIntUpToNDigits(i32, &peek_stream, 2);
            },
            'Y' => {
                if (year != null) return error.FormatHsTooManyYears;
                year = try parseIntUpToNDigits(u16, &peek_stream, 4);
            },
            else => {
                match_literal = true;
            },
        }
        if (match_literal) {
            if ((try peek_stream.reader().readByte()) != c) return error.FailedToMatchLiteral;
        }
    }
    if (year == null) return error.FormatHasNoYear;
    if (month == null) return error.FormatHasNoMonth;
    if (mode == .month) {
        return Month.init(year.?, month.?);
    }
    if (day == null) return error.FormatHasNoDay;
    return Date.init(year.?, month.?, day.?);
}

fn parseIntUpToNDigits(comptime T: type, peek_stream: anytype, comptime digits: usize) !T {
    var value = @as(T, 0);
    var read: usize = 0;
    while (read < digits) : (read += 1) {
        const byte = peek_stream.reader().readByte() catch |err| {
            switch (err) {
                error.EndOfStream => break,
            }
        };
        switch (byte) {
            '0'...'9' => {
                value = value * 10 + @as(T, byte - '0');
            },
            else => {
                try peek_stream.putBackByte(byte);
            },
        }
    }
    if (read == 0) return error.InvalidDay;
    return value;
}

fn parseMonth(peek_stream: anytype) !i32 {
    var month: i32 = 0;
    var read: usize = 0;
    while (read < 2) : (read += 1) {
        const byte = peek_stream.reader().readByte() catch |err| {
            switch (err) {
                error.EndOfStream => break,
            }
        };
        switch (byte) {
            '0'...'9' => {
                month = month.? * 10 + @as(i32, byte - '0');
            },
            else => {
                try peek_stream.putBackByte(byte);
            },
        }
    }
    if (read == 0) return error.InvalidMonth;
}

fn parseYear(peek_stream: anytype) !u16 {
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
}

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

test "format" {
    var buffer = [_]u8{0} ** 24;
    {
        var stream = std.io.fixedBufferStream(buffer[0..]);
        const writer = &stream.writer();
        try writer.print(
            "{Weekday (Day) Month D, 'YY}",
            .{Date.init(2020, 6, 1)},
        );
        testing.expectEqualStrings("Monday (Mon) June 1, '20", stream.buffer);
    }
    {
        var stream = std.io.fixedBufferStream(buffer[0..10]);
        const writer = &stream.writer();
        try writer.print("{YYYY-MM-DD}", .{Date.init(2020, 6, 1)});
        testing.expectEqualStrings("2020-06-01", stream.buffer);
    }
}
test "formatRuntime" {
    var buffer = [_]u8{0} ** 24;
    {
        var stream = std.io.fixedBufferStream(buffer[0..]);
        try Date.init(2020, 6, 1).formatRuntime(
            "Weekday (Day) Month D, 'YY",
            &stream.writer(),
        );
        testing.expectEqualStrings("Monday (Mon) June 1, '20", stream.buffer);
    }
    {
        var stream = std.io.fixedBufferStream(buffer[0..10]);
        try Date.init(2020, 6, 1).formatRuntime(
            "YYYY-MM-DD",
            &stream.writer(),
        );
        testing.expectEqualStrings("2020-06-01", stream.buffer);
    }
}
test "parse" {
    testing.expectEqual(Date.init(2020, 6, 1), try Date.parse("2020-06-01"));
}
test "parseFmt" {
    testing.expectEqual(Date.init(2020, 6, 1), try Date.parseStringFmt("Y/M/D", "2020/6/1"));
    testing.expectEqual(Date.init(2020, 3, 17), try Date.parseStringFmt("Y-M-D", "2020-03-17 19:23:18 PDT"));
    testing.expectEqual(Date.init(2020, 5, 8), try Date.parseStringFmt("M/D/Y", "05/08/2020"));
}
test "parseStringComptimeFmt" {
    testing.expectEqual(Date.init(2020, 6, 1), try Date.parseStringComptimeFmt("Y/M/D", "2020/6/1"));
    testing.expectEqual(Date.init(2020, 3, 17), try Date.parseStringComptimeFmt("Y-M-D", "2020-03-17 19:23:18 PDT"));
    testing.expectEqual(Date.init(2020, 5, 8), try Date.parseStringComptimeFmt("M/D/Y", "05/08/2020"));
}

test "toSring" {
    testing.expectEqualStrings("2021-01-01", Date.init(2021, 1, 1).toString()[0..]);
    testing.expectEqualStrings("2020-06-14", Date.init(2020, 6, 14).toString()[0..]);
}
