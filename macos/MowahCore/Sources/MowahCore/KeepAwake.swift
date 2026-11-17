/// What macOS should be asked to keep awake in a given state.
public struct KeepAwake: Equatable, Sendable {
    public var system: Bool
    public var display: Bool

    public init(system: Bool, display: Bool) {
        self.system = system
        self.display = display
    }
}

public func keepAwake(status: Status, settings: Settings) -> KeepAwake {
    switch status {
    case .userActive, .keepingAlive, .permissionMissing:
        // Without the permission Mowah cannot send input, so holding the Mac
        // awake is the one thing it can still do.
        return KeepAwake(system: settings.preventSleep, display: settings.keepDisplayOn)
    case .locked:
        // A locked Mac keeps running so work in progress survives, but nobody
        // is looking at the screen.
        return KeepAwake(system: settings.preventSleep, display: false)
    case .paused, .pausedUntil, .outsideSchedule:
        return KeepAwake(system: false, display: false)
    }
}
