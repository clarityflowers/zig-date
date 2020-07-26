const std = @import("std");
const testing = std.testing;
const Month = @import("month.zig").Month;
const Date = @import("date.zig").Date;

pub const Week = struct {
    monday: Date,

    pub fn fromDate(date: Date) Week {
        return Week{ .monday = date.minusDays(@enumToInt(date.dayOfWeek()) - 1) };
    }

    pub fn plusWeeks(week: Week, weeks: i32) Week {
        return week.monday.plusDays(weeks * 7).toWeek();
    }

    pub fn minusWeeks(week: Week, weeks: i32) Week {
        return week.plusWeeks(-weeks);
    }
};

test "init" {
    const sunday = Date.init(2020, 3, 1);
    const monday = Date.init(2020, 2, 24);
    testing.expectEqual(Date.init(2020, 2, 24), Week.fromDate(sunday).monday);
    testing.expectEqual(monday, Week.fromDate(monday).monday);
}

test "minusWeeks" {
    testing.expectEqual(Date.init(2020, 3, 9), Date.init(2020, 5, 11).toWeek().minusWeeks(9).monday);
}
