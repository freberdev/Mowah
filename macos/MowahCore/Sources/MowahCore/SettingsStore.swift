import Foundation

/// Reads and writes the settings in a preferences domain. Missing or unreadable
/// values fall back to their defaults, so an old or damaged file never stops the app.
public struct SettingsStore {
    private enum Key {
        static let method = "method"
        static let circleDiameter = "circle_diameter_px"
        static let idleThreshold = "idle_threshold_secs"
        static let intervalMin = "interval_min_secs"
        static let intervalMax = "interval_max_secs"
        static let leftClick = "left_click"
        static let preventSleep = "prevent_sleep"
        static let keepDisplayOn = "keep_display_on"
        static let scheduleEnabled = "schedule_enabled"
        static let scheduleStart = "schedule_start"
        static let scheduleEnd = "schedule_end"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// True until something has been saved.
    public var isFirstRun: Bool {
        defaults.object(forKey: Key.method) == nil
    }

    public func load() -> Settings {
        var s = Settings()
        // `as?` on the stored object, not `integer(forKey:)`: the typed getters turn
        // a missing or mistyped value into 0 or false instead of saying it is absent.
        func int(_ key: String) -> Int? { defaults.object(forKey: key) as? Int }
        func bool(_ key: String) -> Bool? { defaults.object(forKey: key) as? Bool }
        func time(_ key: String) -> Int? { (defaults.object(forKey: key) as? String).flatMap(parseTime) }

        if let raw = defaults.object(forKey: Key.method) as? String, let method = Method(rawValue: raw) {
            s.method = method
        }
        s.circleDiameter = int(Key.circleDiameter) ?? s.circleDiameter
        s.idleThresholdSecs = int(Key.idleThreshold) ?? s.idleThresholdSecs
        s.intervalMinSecs = int(Key.intervalMin) ?? s.intervalMinSecs
        s.intervalMaxSecs = int(Key.intervalMax) ?? s.intervalMaxSecs
        s.leftClick = bool(Key.leftClick) ?? s.leftClick
        s.preventSleep = bool(Key.preventSleep) ?? s.preventSleep
        s.keepDisplayOn = bool(Key.keepDisplayOn) ?? s.keepDisplayOn
        s.scheduleEnabled = bool(Key.scheduleEnabled) ?? s.scheduleEnabled
        s.scheduleStartMinute = time(Key.scheduleStart) ?? s.scheduleStartMinute
        s.scheduleEndMinute = time(Key.scheduleEnd) ?? s.scheduleEndMinute
        return s.normalized()
    }

    public func save(_ settings: Settings) {
        defaults.set(settings.method.rawValue, forKey: Key.method)
        defaults.set(settings.circleDiameter, forKey: Key.circleDiameter)
        defaults.set(settings.idleThresholdSecs, forKey: Key.idleThreshold)
        defaults.set(settings.intervalMinSecs, forKey: Key.intervalMin)
        defaults.set(settings.intervalMaxSecs, forKey: Key.intervalMax)
        defaults.set(settings.leftClick, forKey: Key.leftClick)
        defaults.set(settings.preventSleep, forKey: Key.preventSleep)
        defaults.set(settings.keepDisplayOn, forKey: Key.keepDisplayOn)
        defaults.set(settings.scheduleEnabled, forKey: Key.scheduleEnabled)
        defaults.set(formatTime(settings.scheduleStartMinute), forKey: Key.scheduleStart)
        defaults.set(formatTime(settings.scheduleEndMinute), forKey: Key.scheduleEnd)
    }
}
