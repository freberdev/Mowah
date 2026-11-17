import Foundation

/// Everything the engine needs to know about the outside world for one tick.
public struct TickInput: Sendable {
    /// A clock in milliseconds that keeps running while the Mac sleeps.
    public var nowMs: UInt64
    /// Time since the system last saw any input, including input Mowah sent.
    public var systemIdleMs: UInt64
    public var local: LocalTime
    public var locked: Bool
    /// Whether macOS lets Mowah send input at all (the Accessibility permission).
    public var hasPermission: Bool

    public init(nowMs: UInt64, systemIdleMs: UInt64, local: LocalTime, locked: Bool, hasPermission: Bool) {
        self.nowMs = nowMs
        self.systemIdleMs = systemIdleMs
        self.local = local
        self.locked = locked
        self.hasPermission = hasPermission
    }
}

public enum Status: Equatable, Sendable {
    /// Paused by the user until they resume.
    case paused
    /// Paused by the user for a fixed time.
    case pausedUntil
    /// The screen is locked.
    case locked
    case outsideSchedule
    /// macOS has not given Mowah permission to send input.
    case permissionMissing
    /// On duty, but the user is working so nothing is sent.
    case userActive
    /// The user is away and Mowah is producing activity.
    case keepingAlive

    /// True when Mowah is on duty, whether or not it is sending input right now.
    public var isArmed: Bool {
        self == .userActive || self == .keepingAlive
    }
}

public struct Outcome: Equatable, Sendable {
    public var status: Status
    /// True when the caller should perform one activity action now.
    public var act: Bool
    /// How long the real user has been away, ignoring Mowah's own input.
    public var userIdleMs: UInt64
}

public final class Engine {
    /// Input that arrives while one of Mowah's own actions is running, or within
    /// this long after it finished, is taken to be that action and not the user.
    /// It is longer than on Windows because the idle clock on a Mac can show a
    /// sent event up to half a second late. Erring short is the safe side: if
    /// Mowah mistakes its own input for the user it merely waits one idle
    /// threshold before acting again.
    public static let ownInputWindowMs: UInt64 = 1_500

    /// How much earlier than the action Mowah's own input may appear to be. The
    /// idle clock on a Mac is coarse: it can place an event up to about half a
    /// second before the moment the event was sent. The price is that real input
    /// from the last half second before an action is taken for Mowah's own; a
    /// user who goes on working is seen at their next input.
    static let earlyStampAllowanceMs: UInt64 = 600

    private enum Pause: Equatable {
        case none, manual, until(UInt64)
    }

    private let randomSeconds: (ClosedRange<Int>) -> Int
    private var pauseState = Pause.none
    /// Timestamp of the newest system input already accounted for.
    private var lastInputSeenMs: UInt64?
    /// When the real user last touched mouse or keyboard.
    private var userLastActiveMs: UInt64 = 0
    /// Start and end of Mowah's latest action; input around this span is its own.
    private var ownAction: (start: UInt64, end: UInt64)?
    private var nextActionMs: UInt64?

    public init(randomSeconds: @escaping (ClosedRange<Int>) -> Int = { Int.random(in: $0) }) {
        self.randomSeconds = randomSeconds
    }

    public func tick(_ settings: Settings, _ input: TickInput) -> Outcome {
        let now = input.nowMs
        // An idle time longer than the clock's own value would wrap; treat it as
        // "since the clock started".
        noteSystemInput(at: now >= input.systemIdleMs ? now - input.systemIdleMs : 0)
        let userIdleMs = now >= userLastActiveMs ? now - userLastActiveMs : 0

        if case .until(let deadline) = pauseState, now >= deadline {
            pauseState = .none
        }

        let status: Status
        switch pauseState {
        case .manual:
            status = .paused
        case .until:
            status = .pausedUntil
        case .none:
            if input.locked {
                status = .locked
            } else if !isWithinSchedule(settings, at: input.local) {
                status = .outsideSchedule
            } else if !input.hasPermission {
                status = .permissionMissing
            } else if userIdleMs < UInt64(settings.idleThresholdSecs) * 1_000 {
                status = .userActive
            } else {
                status = .keepingAlive
            }
        }

        guard status == .keepingAlive else {
            // Forget the cadence so the next away period starts with an immediate action.
            nextActionMs = nil
            return Outcome(status: status, act: false, userIdleMs: userIdleMs)
        }

        let act = nextActionMs.map { now >= $0 } ?? true
        if act {
            let low = min(settings.intervalMinSecs, settings.intervalMaxSecs)
            let high = max(settings.intervalMinSecs, settings.intervalMaxSecs)
            let waitSecs = max(1, randomSeconds(low...high))
            ownAction = (now, now)
            nextActionMs = now + UInt64(waitSecs) * 1_000
        }
        return Outcome(status: status, act: act, userIdleMs: userIdleMs)
    }

    /// Decides whether newly observed system input came from the user or from Mowah.
    private func noteSystemInput(at inputMs: UInt64) {
        if let seen = lastInputSeenMs, inputMs <= seen { return }
        lastInputSeenMs = inputMs
        if let own = ownAction, inputMs + Engine.earlyStampAllowanceMs >= own.start, inputMs <= own.end + Engine.ownInputWindowMs { return }
        userLastActiveMs = inputMs
    }

    /// Tells the engine that the action it asked for has now been carried out. A
    /// visible pointer movement takes a while, and input up to this moment is Mowah's.
    public func actionFinished(nowMs: UInt64) {
        if let own = ownAction {
            ownAction = (own.start, max(own.start, nowMs))
        }
    }

    /// Tells the engine that the user took over the mouse while an action was running.
    public func userInterrupted(nowMs: UInt64) {
        ownAction = nil
        userLastActiveMs = nowMs
        // Whatever input the system recorded up to now has been dealt with here.
        lastInputSeenMs = max(lastInputSeenMs ?? nowMs, nowMs)
    }

    public func pause() { pauseState = .manual }
    public func pause(untilMs deadline: UInt64) { pauseState = .until(deadline) }
    public func resume() { pauseState = .none }
    public var isPaused: Bool { pauseState != .none }
}
