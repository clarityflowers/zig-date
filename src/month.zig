const std = @import("std");
const io = std.io;
const testing = std.testing;
const date = @import("date.zig");
const parse = @import("parse.zig");
const ParseResult = parse.ParseResult;
const matchLiteral = parse.matchLiteral;
const parseResult = parse.parseResult;

pub const CalendarMonth = enum(u4) { January = 1, February = 2, March = 3, April = 4, May = 5, June = 6, July = 7, August = 8, September = 9, October = 10, November = 11, December = 12 };

fn isLeapYear(year: u16) bool {
    return (year % 4 == 0 and (year % 100 != 0 or year % 400 == 0));
}

fn startingWeekdayOfYear(year: u16) bool {
    if (year == 2020) return 3;
    var y = 2020;
    var d = 3;
    if (year > 2020) {
        while (y < year) {
            d += if (isLeapYear(y)) 2 else 1;
            y += 1;
        }
    }
    if (year < 2020) {
        while (y > year) {
            y -= 1;
            d -= if (isLeapYear(y)) 2 else 1;
        }
    }
    d = @mod(d, 7);
    return if (d == 0) 7 else d;
}

pub const Month = struct {
    year: u16,
    month: CalendarMonth,

    pub fn init(year: u16, month: i32) Month {
        var y = year;
        var m = month;
        while (m > 12) {
            m -= 12;
            y += 1;
        }
        while (m < 1) {
            m += 12;
            y -= 1;
        }
        return Month{
            .year = y,
            .month = @intToEnum(CalendarMonth, @intCast(u4, m)),
        };
    }

    pub fn plusMonths(month: Month, months: i32) Month {
        return Month.init(month.year, @as(i32, @enumToInt(month.month)) + months);
    }
    pub fn minusMonths(month: Month, months: i32) Month {
        return month.plusMonths(-months);
    }

    pub fn numberOfDays(month: Month) i32 {
        const result: i32 = switch (month.month) {
            .February => 28,
            .January, .March, .May, .July, .August, .October, .December => 31,
            .April,
            .June,
            .September,
            .November,
            => 30,
        };
        if (result == 28 and isLeapYear(month.year)) return 29;
        return result;
    }

    pub fn isAfter(month: Month, other: Month) bool {
        return month.year > other.year or @enumToInt(month.month) > @enumToInt(other.month);
    }

    pub fn isBefore(month: Month, other: Month) bool {
        return other.isAfter(month);
    }

    pub fn isOnOrAfter(month: Month, other: Month) bool {
        return month.year >= other.year or @enumToInt(month.month) >= @enumToInt(other.month);
    }

    pub fn isOnOrBefore(month: Month, other: Month) bool {
        return other.isOnOrAfter(month);
    }

    pub fn equals(month: Month, other: Month) bool {
        return month.year == other.year and month.month == other.month;
    }

    /// The format keywords are listed below. Any other characters are reproduced literally.
    /// M - the month as one or two digits (1, 10)
    /// MM - the month as two digits (01, 10)
    /// Month - the month, written out (January, October)
    /// YY - the year as two digits (98, 20)
    /// YYYY - the year as four digits (1998, 2020)
    pub fn format(value: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = options;
        if (fmt.len == 0) return writer.print("{YYYY-MM}", .{value});
        const tokens = comptime blk: {
            var stream = FormatTokenStream{ .fmt = fmt };
            var tokens: []const FormatToken = &[0]FormatToken{};
            inline while (stream.next()) |token| {
                tokens = tokens ++ &[1]FormatToken{token};
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
        if (fmt.len == 0) return writer.print("{YYYY-MM}", .{value});
        var stream = FormatTokenStream{ .fmt = fmt };
        while (stream.next()) |token| {
            try token.print(value, writer);
        }
    }

    pub fn toString(self: Month) [7]u8 {
        var buffer: [7]u8 = undefined;
        const writer = std.io.fixedBufferStream(@as([]u8, &buffer)).writer();
        writer.print("{}", .{self}) catch unreachable;
        return buffer;
    }

    pub fn parse(string: []const u8) !@This() {
        return parseStringComptimeFmt("Y-M", string);
    }

    pub fn parseFmt(fmt: []const u8, reader: anytype) !@This() {
        return date.parseDateFmt(fmt, .month, reader);
    }

    pub fn parseStringFmt(fmt: []const u8, str: []const u8) !@This() {
        const reader = io.fixedBufferStream(str).reader();
        return parseFmt(fmt, reader);
    }

    pub fn parseComptimeFmt(comptime fmt: []const u8, reader: anytype) !@This() {
        return date.parseDateComptimeFmt(fmt, .month, reader);
    }

    pub fn parseStringComptimeFmt(comptime fmt: []const u8, str: []const u8) !@This() {
        const reader = io.fixedBufferStream(str).reader();
        return parseComptimeFmt(fmt, reader);
    }
};

pub const FormatToken = union(enum) {
    month_1digit,
    month_2digit,
    month_short,
    month_long,
    year_2digit,
    year_4digit,
    literal: u8,

    pub fn print(self: @This(), value: Month, writer: anytype) !void {
        switch (self) {
            .month_1digit => {
                try writer.print("{d}", .{@enumToInt(value.month)});
            },
            .month_2digit => {
                try writer.print("{d:0>2}", .{@enumToInt(value.month)});
            },
            .month_short => {
                try writer.writeAll(@tagName(value.month)[0..3]);
            },
            .month_long => {
                try writer.writeAll(@tagName(value.month));
            },
            .year_2digit => {
                const last_two_digits = value.year -
                    @divTrunc(value.year, 100) * 100;
                try writer.print("{d:0>2}", .{last_two_digits});
            },
            .year_4digit => {
                try writer.print("{d:0>4}", .{value.year});
            },
            .literal => |literal| try writer.writeByte(literal),
        }
    }
};

pub fn parseFormatToken(
    fmt: []const u8,
    start: usize,
) ?ParseResult(FormatToken) {
    if (matchLiteral(fmt, start, "MM")) |index| {
        return parseResult(FormatToken{ .month_2digit = {} }, index);
    } else if (matchLiteral(fmt, start, "Month")) |index| {
        return parseResult(FormatToken{ .month_long = {} }, index);
    } else if (matchLiteral(fmt, start, "Mon")) |index| {
        return parseResult(FormatToken{ .month_short = {} }, index);
    } else if (matchLiteral(fmt, start, "M")) |index| {
        return parseResult(FormatToken{ .month_1digit = {} }, index);
    } else if (matchLiteral(fmt, start, "YYYY")) |index| {
        return parseResult(FormatToken{ .year_4digit = {} }, index);
    } else if (matchLiteral(fmt, start, "YY")) |index| {
        return parseResult(FormatToken{ .year_2digit = {} }, index);
    } else return null;
}

const FormatTokenStream = struct {
    fmt: []const u8,
    index: usize = 0,

    fn next(self: *@This()) ?FormatToken {
        if (self.index >= self.fmt.len) return null;
        if (parseFormatToken(self.fmt, self.index)) |res| {
            self.index = res.new_pos;
            return res.data;
        } else {
            defer self.index += 1;
            return FormatToken{
                .literal = self.fmt[self.index],
            };
        }
    }
};

test "can create month" {
    testing.expectEqual(Month{ .year = 2020, .month = .May }, Month.init(2020, 5));
}

test "can wrap months around years" {
    testing.expectEqual(Month{ .year = 2021, .month = .February }, Month.init(2020, 14));
    testing.expectEqual(Month{ .year = 2019, .month = .August }, Month.init(2020, -4));
}

test "can add and subtract months" {
    testing.expectEqual(Month{ .year = 2021, .month = .January }, Month.init(2020, 8).plusMonths(5));
    testing.expectEqual(Month{ .year = 2020, .month = .February }, Month.init(2020, 5).minusMonths(3));
}

test "number of days" {
    testing.expectEqual(@as(i32, 31), Month.init(2020, 12).numberOfDays());
    testing.expectEqual(@as(i32, 28), Month.init(2019, 2).numberOfDays());
    testing.expectEqual(@as(i32, 29), Month.init(2020, 2).numberOfDays());
    testing.expectEqual(@as(i32, 28), Month.init(2100, 2).numberOfDays());
    testing.expectEqual(@as(i32, 29), Month.init(2000, 2).numberOfDays());
}

test "is before or after" {
    testing.expect(Month.init(2020, 5).isAfter(Month.init(2020, 3)));
    testing.expect(Month.init(2020, 5).isAfter(Month.init(2018, 12)));
    testing.expect(!Month.init(2020, 5).isAfter(Month.init(2020, 5)));
    testing.expect(Month.init(2020, 5).isBefore(Month.init(2021, 3)));
    testing.expect(!Month.init(2020, 5).isBefore(Month.init(2020, 5)));
}

test "isOnOrBefore and isOnOrAfter" {
    testing.expect(Month.init(2020, 5).isOnOrAfter(Month.init(2020, 3)));
    testing.expect(Month.init(2020, 5).isOnOrAfter(Month.init(2018, 12)));
    testing.expect(Month.init(2020, 5).isOnOrAfter(Month.init(2020, 5)));
    testing.expect(Month.init(2020, 5).isOnOrBefore(Month.init(2021, 3)));
    testing.expect(Month.init(2020, 5).isOnOrBefore(Month.init(2020, 5)));
}

test "format" {
    var buffer = [_]u8{0} ** 9;
    {
        var stream = std.io.fixedBufferStream(buffer[0..]);
        const writer = &stream.writer();
        try writer.print("{Month, 'YY}", .{Month.init(2020, 6)});
        testing.expectEqualStrings("June, '20", stream.buffer);
    }
    {
        var stream = std.io.fixedBufferStream(buffer[0..7]);
        const writer = &stream.writer();
        try writer.print("{}", .{Month.init(2020, 6)});
        testing.expectEqualStrings("2020-06", stream.buffer);
    }
}
test "formatRuntime" {
    var buffer = [_]u8{0} ** 9;
    {
        var stream = std.io.fixedBufferStream(buffer[0..]);
        try Month.init(2020, 6).formatRuntime("Month, 'YY", &stream.writer());
        testing.expectEqualStrings("June, '20", stream.buffer);
    }
    {
        var stream = std.io.fixedBufferStream(buffer[0..7]);
        try Month.init(2020, 6).formatRuntime("", &stream.writer());
        testing.expectEqualStrings("2020-06", stream.buffer);
    }
}
test "parse" {
    testing.expectEqual(Month.init(2020, 5), try Month.parse("2020-05"));
    testing.expectEqual(Month.init(2008, 7), try Month.parseStringFmt("Y-M", "2008-7"));
    testing.expectEqual(Month.init(1970, 1), try Month.parseStringFmt("M/Y", "1/1970"));
    testing.expectEqual(Month.init(2008, 7), try Month.parseStringComptimeFmt("Y-M", "2008-7"));
    testing.expectEqual(Month.init(1970, 1), try Month.parseStringComptimeFmt("M/Y", "1/1970"));
}
