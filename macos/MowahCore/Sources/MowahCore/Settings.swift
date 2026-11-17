import Foundation

/// How Mowah produces activity once the user has been away.
public enum Method: String, CaseIterable, Sendable {
    /// A mouse event at the pointer's own position. Nothing moves.
    case invisible
    /// The pointer draws a circle.
    case visibleMove = "visible_move"
    /// A press of F20, a key with no meaning of its own on a Mac.
    case key
}

public struct Settings: Equatable, Sendable {
    /// Shortest and longest allowed timing values. The upper bound stays under
    /// five minutes because that is when Teams marks a user as away.
    public static let secondsRange = 5...240
    /// Smallest and largest circle the visible movement may draw, in points.
    public static let circleRange = 20...1000

    static let defaultScheduleStart = 8 * 60
    static let defaultScheduleEnd = 17 * 60
    static let minutesPerDay = 24 * 60

    public var method: Method = .invisible
    public var circleDiameter = 300
    public var idleThresholdSecs = 60
    public var intervalMinSecs = 30
    public var intervalMaxSecs = 90
    public var leftClick = false
    public var preventSleep = true
    public var keepDisplayOn = true
    public var scheduleEnabled = false
    /// Minutes since midnight.
    public var scheduleStartMinute = Settings.defaultScheduleStart
    public var scheduleEndMinute = Settings.defaultScheduleEnd

    public init() {}

    /// A copy with every value forced into its valid range.
    public func normalized() -> Settings {
        var s = self
        let seconds = Settings.secondsRange
        s.circleDiameter = circleDiameter.clamped(to: Settings.circleRange)
        s.idleThresholdSecs = idleThresholdSecs.clamped(to: seconds)
        s.intervalMinSecs = intervalMinSecs.clamped(to: seconds)
        s.intervalMaxSecs = intervalMaxSecs.clamped(to: s.intervalMinSecs...seconds.upperBound)
        if !(0..<Settings.minutesPerDay).contains(scheduleStartMinute) {
            s.scheduleStartMinute = Settings.defaultScheduleStart
        }
        if !(0..<Settings.minutesPerDay).contains(scheduleEndMinute) {
            s.scheduleEndMinute = Settings.defaultScheduleEnd
        }
        return s
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

/// Reads a number field: ASCII digits only, with surrounding spaces allowed.
/// Signs, decimals, group separators and other scripts' digits are not a whole
/// number here, so the field keeps its previous value instead of guessing.
public func parseWholeNumber(_ text: String) -> Int? {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty, trimmed.count <= 9, trimmed.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
    return Int(trimmed)
}

/// Parses "8:05", "08:05" or "08.05" into minutes since midnight.
public func parseTime(_ text: String) -> Int? {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    let parts = trimmed.split(omittingEmptySubsequences: false, whereSeparator: { $0 == ":" || $0 == "." })
    guard parts.count == 2 else { return nil }
    // ASCII digits only: Int() would also accept a sign, and other scripts' digits
    // would not round-trip through formatTime.
    func number(_ part: Substring) -> Int? {
        guard (1...2).contains(part.count), part.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(part)
    }
    guard let hours = number(parts[0]), let minutes = number(parts[1]), hours < 24, minutes < 60 else { return nil }
    return hours * 60 + minutes
}

public func formatTime(_ minuteOfDay: Int) -> String {
    String(format: "%02d:%02d", minuteOfDay / 60, minuteOfDay % 60)
}

/// How many pointer positions a circle of this size is drawn with: enough to look
/// round, few enough that even the largest circle is over in a couple of seconds.
public func circleSteps(diameter: Int) -> Int {
    let pointsPerStep = 15.0
    let circumference = Double.pi * Double(diameter)
    return Int((circumference / pointsPerStep).rounded()).clamped(to: 24...96)
}
