import Foundation
import Testing
@testable import MowahCore

@Suite struct ScheduleTests {
    private let sun = 0, mon = 1, fri = 5, sat = 6

    private func at(_ weekday: Int, _ hour: Int, _ minute: Int) -> LocalTime {
        LocalTime(weekday: weekday, minuteOfDay: hour * 60 + minute)
    }

    private var officeHours: Settings {
        var s = Settings()
        s.scheduleEnabled = true
        return s
    }

    private var nightShift: Settings {
        var s = Settings()
        s.scheduleEnabled = true
        s.scheduleStartMinute = 22 * 60
        s.scheduleEndMinute = 6 * 60
        return s
    }

    @Test func disabledScheduleAllowsAnyTime() {
        #expect(isWithinSchedule(Settings(), at: at(sun, 3, 0)))
        #expect(isWithinSchedule(Settings(), at: at(sat, 23, 59)))
    }

    @Test func weekdayInsideHoursIsAllowed() {
        #expect(isWithinSchedule(officeHours, at: at(mon, 9, 0)))
        #expect(isWithinSchedule(officeHours, at: at(fri, 16, 59)))
    }

    @Test func startIsInclusiveAndEndIsExclusive() {
        #expect(isWithinSchedule(officeHours, at: at(mon, 8, 0)))
        #expect(!isWithinSchedule(officeHours, at: at(mon, 7, 59)))
        #expect(!isWithinSchedule(officeHours, at: at(mon, 17, 0)))
    }

    @Test func weekendsAreOutsideSchedule() {
        #expect(!isWithinSchedule(officeHours, at: at(sat, 10, 0)))
        #expect(!isWithinSchedule(officeHours, at: at(sun, 10, 0)))
    }

    @Test func nightShiftCoversBothSidesOfMidnight() {
        #expect(isWithinSchedule(nightShift, at: at(mon, 23, 0)))
        #expect(isWithinSchedule(nightShift, at: at(fri, 5, 59)))
        #expect(!isWithinSchedule(nightShift, at: at(mon, 12, 0)))
        #expect(!isWithinSchedule(nightShift, at: at(mon, 6, 0)))
    }

    @Test func nightShiftBelongsToTheDayItStarted() {
        // Friday's shift runs into Saturday morning; Sunday's never started.
        #expect(isWithinSchedule(nightShift, at: at(sat, 1, 0)))
        #expect(!isWithinSchedule(nightShift, at: at(mon, 1, 0)))
        #expect(!isWithinSchedule(nightShift, at: at(sat, 23, 0)))
    }

    @Test func equalStartAndEndMeansTheWholeWeekday() {
        var s = Settings()
        s.scheduleEnabled = true
        s.scheduleStartMinute = 8 * 60
        s.scheduleEndMinute = 8 * 60
        #expect(isWithinSchedule(s, at: at(mon, 3, 0)))
        #expect(isWithinSchedule(s, at: at(fri, 23, 0)))
        #expect(!isWithinSchedule(s, at: at(sat, 12, 0)))
    }

    @Test func localTimeWeekdayIsGregorianRegardlessOfUserCalendar() throws {
        let stockholm = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let formatter = ISO8601DateFormatter()
        // Monday 16 November 2026, 12:00 in Stockholm (UTC+1).
        let monday = try #require(formatter.date(from: "2026-11-16T11:00:00Z"))
        #expect(LocalTime(date: monday, timeZone: stockholm) == LocalTime(weekday: 1, minuteOfDay: 720))
        // Sunday 15 November 2026, 23:30 in Stockholm.
        let sunday = try #require(formatter.date(from: "2026-11-15T22:30:00Z"))
        #expect(LocalTime(date: sunday, timeZone: stockholm) == LocalTime(weekday: 0, minuteOfDay: 1410))
    }

    @Test func localTimeFollowsTheGivenTimeZone() throws {
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let date = try #require(ISO8601DateFormatter().date(from: "2026-11-15T22:30:00Z"))
        // 07:30 on Monday in Tokyo (UTC+9).
        #expect(LocalTime(date: date, timeZone: tokyo) == LocalTime(weekday: 1, minuteOfDay: 450))
    }
}
