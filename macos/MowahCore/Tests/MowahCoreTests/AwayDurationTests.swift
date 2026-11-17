import Testing
@testable import MowahCore

@Suite struct AwayDurationTests {
    @Test func underAMinuteIsShownInSeconds() {
        #expect(AwayDuration(ms: 0) == .seconds(0))
        #expect(AwayDuration(ms: 59_999) == .seconds(59))
    }

    @Test func underAnHourIsShownInWholeMinutes() {
        #expect(AwayDuration(ms: 60_000) == .minutes(1))
        #expect(AwayDuration(ms: 3_599_000) == .minutes(59))
    }

    @Test func anHourOrMoreIsShownInHoursAndMinutes() {
        #expect(AwayDuration(ms: 3_600_000) == .hoursAndMinutes(1, 0))
        #expect(AwayDuration(ms: 9_000_000) == .hoursAndMinutes(2, 30))
    }
}
