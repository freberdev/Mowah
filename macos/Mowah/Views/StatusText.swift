import Foundation
import MowahCore

/// The main status line, in the chosen language.
func statusLine(_ snapshot: Snapshot, _ texts: Texts) -> String {
    switch snapshot.status {
    case .userActive:
        return texts("status.ready")
    case .keepingAlive:
        return texts.format("status.keepingAlive", durationText(AwayDuration(ms: snapshot.userIdleMs), texts))
    case .paused:
        return texts("status.paused")
    case .pausedUntil:
        guard let end = snapshot.pauseEndMinute else { return texts("status.paused") }
        return texts.format("status.pausedUntil", clockTime(minuteOfDay: end))
    case .outsideSchedule:
        return texts("status.outsideSchedule")
    case .locked:
        return texts("status.locked")
    case .permissionMissing:
        return texts("status.permissionMissing")
    }
}

/// The line under the status: when Mowah last did something.
func lastActionLine(_ snapshot: Snapshot, _ texts: Texts) -> String {
    guard let minute = snapshot.lastActionMinute else { return texts("lastAction.none") }
    return texts.format("lastAction.at", clockTime(minuteOfDay: minute))
}

private func durationText(_ duration: AwayDuration, _ texts: Texts) -> String {
    switch duration {
    case .seconds(let seconds):
        return texts.format("duration.seconds", seconds)
    case .minutes(let minutes):
        return texts.format("duration.minutes", minutes)
    case .hoursAndMinutes(let hours, let minutes):
        return texts.format("duration.hoursAndMinutes", hours, minutes)
    }
}

/// A time of day written the way the Mac is set up to show it, with 12 or 24 hours.
private func clockTime(minuteOfDay: Int) -> String {
    let midnight = Calendar.current.startOfDay(for: Date())
    let date = midnight.addingTimeInterval(TimeInterval(minuteOfDay * 60))
    return date.formatted(date: .omitted, time: .shortened)
}
