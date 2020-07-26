const std = @import("std");
const testing = std.testing;

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
