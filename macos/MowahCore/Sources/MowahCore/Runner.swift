/// The parts of macOS the runner needs. The app supplies the real ones, the
/// tests a stand-in.
public protocol SystemServices: AnyObject {
    /// A clock in milliseconds that keeps running while the Mac sleeps.
    var nowMs: UInt64 { get }
    var localTime: LocalTime { get }
    /// Time since the system last saw any input.
    var systemIdleMs: UInt64 { get }
    var isLocked: Bool { get }
    var hasPermission: Bool { get }
    /// Performs one round of activity. Returns false if the user took over the mouse.
    func perform(_ settings: Settings) -> Bool
    func hold(_ needs: KeepAwake)
}

/// What the app shows after a tick.
public struct Snapshot: Equatable, Sendable {
    public var status: Status
    public var userIdleMs: UInt64
    public var isPaused: Bool
    /// Minute of day of the latest completed action.
    public var lastActionMinute: Int?
    /// Minute of day a timed pause ends, while one is running.
    public var pauseEndMinute: Int?

    public init(status: Status, userIdleMs: UInt64, isPaused: Bool, lastActionMinute: Int?, pauseEndMinute: Int?) {
        self.status = status
        self.userIdleMs = userIdleMs
        self.isPaused = isPaused
        self.lastActionMinute = lastActionMinute
        self.pauseEndMinute = pauseEndMinute
    }
}

/// Runs one tick at a time: asks the engine what to do, does it, and reports.
public final class Runner {
    private static let hourMs: UInt64 = 3_600_000
    private static let minutesPerDay = 24 * 60

    private let engine: Engine
    private let services: SystemServices
    public var settings: Settings
    private var lastActionMinute: Int?
    private var pauseEndMinute: Int?

    public init(engine: Engine, services: SystemServices, settings: Settings) {
        self.engine = engine
        self.services = services
        self.settings = settings
    }

    public func tick() -> Snapshot {
        let input = TickInput(
            nowMs: services.nowMs,
            systemIdleMs: services.systemIdleMs,
            local: services.localTime,
            locked: services.isLocked,
            hasPermission: services.hasPermission
        )
        let outcome = engine.tick(settings, input)

        if outcome.act {
            // The clock is read again afterwards: a visible movement takes a while.
            if services.perform(settings) {
                engine.actionFinished(nowMs: services.nowMs)
                lastActionMinute = services.localTime.minuteOfDay
            } else {
                engine.userInterrupted(nowMs: services.nowMs)
            }
        }
        services.hold(keepAwake(status: outcome.status, settings: settings))

        return Snapshot(
            status: outcome.status,
            userIdleMs: outcome.userIdleMs,
            isPaused: engine.isPaused,
            lastActionMinute: lastActionMinute,
            pauseEndMinute: outcome.status == .pausedUntil ? pauseEndMinute : nil
        )
    }

    public func togglePause() {
        if engine.isPaused {
            engine.resume()
        } else {
            engine.pause()
        }
        pauseEndMinute = nil
    }

    public func pauseForAnHour() {
        engine.pause(untilMs: services.nowMs + Runner.hourMs)
        pauseEndMinute = (services.localTime.minuteOfDay + 60) % Runner.minutesPerDay
    }
}
