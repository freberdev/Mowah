import Foundation

public struct LocalTime: Equatable, Sendable {
    /// 0 = Sunday … 6 = Saturday.
    public var weekday: Int
    public var minuteOfDay: Int

    public init(weekday: Int, minuteOfDay: Int) {
        self.weekday = weekday
        self.minuteOfDay = minuteOfDay
    }

    /// Always read with the Gregorian calendar. The user's own calendar may start
    /// the week on another day or not be Gregorian at all, and Monday to Friday
    /// has to mean the same days regardless.
    public init(date: Date, timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        self.weekday = (parts.weekday ?? 1) - 1
        self.minuteOfDay = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}

/// True when Mowah is allowed to work at `now`. With the schedule switched off
/// that is always; otherwise Monday to Friday between the start and end time. An
/// end time earlier than the start means a shift that runs past midnight.
public func isWithinSchedule(_ settings: Settings, at now: LocalTime) -> Bool {
    guard settings.scheduleEnabled else { return true }
    let start = settings.scheduleStartMinute
    let end = settings.scheduleEndMinute
    let today = ((now.weekday % 7) + 7) % 7
    let yesterday = (today + 6) % 7
    func isWorkday(_ weekday: Int) -> Bool { (1...5).contains(weekday) }

    if start == end {
        return isWorkday(today)
    } else if start < end {
        return isWorkday(today) && now.minuteOfDay >= start && now.minuteOfDay < end
    } else {
        return (isWorkday(today) && now.minuteOfDay >= start) || (isWorkday(yesterday) && now.minuteOfDay < end)
    }
}
