import Foundation
import MowahCore

/// The main status line, in the user's language.
func statusLine(_ snapshot: Snapshot) -> String {
    switch snapshot.status {
    case .userActive:
        return String(localized: "status.ready")
    case .keepingAlive:
        return formatted("status.keepingAlive", durationText(AwayDuration(ms: snapshot.userIdleMs)))
    case .paused:
        return String(localized: "status.paused")
    case .pausedUntil:
        guard let end = snapshot.pauseEndMinute else { return String(localized: "status.paused") }
        return formatted("status.pausedUntil", clockTime(minuteOfDay: end))
    case .outsideSchedule:
        return String(localized: "status.outsideSchedule")
    case .locked:
        return String(localized: "status.locked")
    case .permissionMissing:
        return String(localized: "status.permissionMissing")
    }
}

/// The line under the status: when Mowah last did something.
func lastActionLine(_ snapshot: Snapshot) -> String {
    guard let minute = snapshot.lastActionMinute else { return String(localized: "lastAction.none") }
    return formatted("lastAction.at", clockTime(minuteOfDay: minute))
}

private func durationText(_ duration: AwayDuration) -> String {
    switch duration {
    case .seconds(let seconds):
        return formatted("duration.seconds", seconds)
    case .minutes(let minutes):
        return formatted("duration.minutes", minutes)
    case .hoursAndMinutes(let hours, let minutes):
        return formatted("duration.hoursAndMinutes", hours, minutes)
    }
}

/// A time of day written the way the Mac is set up to show it, with 12 or 24 hours.
private func clockTime(minuteOfDay: Int) -> String {
    let midnight = Calendar.current.startOfDay(for: Date())
    let date = midnight.addingTimeInterval(TimeInterval(minuteOfDay * 60))
    return date.formatted(date: .omitted, time: .shortened)
}

/// Looks up a text with placeholders and fills them in.
private func formatted(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
    String(format: String(localized: key), locale: .current, arguments: arguments)
}
