const std = @import("std");
const io = std.io;
const testing = std.testing;
const date = @import("date.zig");

pub const CalendarMonth = enum {
    January = 1, February = 2, March = 3, April = 4, May = 5, June = 6, July = 7, August = 8, September = 9, October = 10, November = 11, December = 12
};

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
        if (fmt.len == 0) return writer.print("{YYYY-MM}", .{value});
        return date.formatDate(fmt, writer, value, null);
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
        const out_stream = &stream.outStream();
        try out_stream.print("{Month, 'YY}", .{Month.init(2020, 6)});
        testing.expectEqualStrings("June, '20", stream.buffer);
    }
    {
        var stream = std.io.fixedBufferStream(buffer[0..7]);
        const out_stream = &stream.outStream();
        try out_stream.print("{}", .{Month.init(2020, 6)});
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
