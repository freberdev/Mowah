import Testing
@testable import MowahCore

/// Stands in for macOS. An action that completes shows up as system input.
private final class FakeServices: SystemServices {
    var nowMs: UInt64 = 1_000_000
    var localTime = LocalTime(weekday: 1, minuteOfDay: 12 * 60)
    var lastInputMs: UInt64 = 1_000_000
    var isLocked = false
    var hasPermission = true
    /// What `perform` returns: false means the user took over the mouse.
    var actionsComplete = true
    var performCount = 0
    var held: [KeepAwake] = []

    var systemIdleMs: UInt64 { nowMs >= lastInputMs ? nowMs - lastInputMs : 0 }

    func perform(_ settings: Settings) -> Bool {
        performCount += 1
        // Either Mowah's own input or the user's: the system clock resets both ways.
        lastInputMs = nowMs
        return actionsComplete
    }

    func hold(_ needs: KeepAwake) { held.append(needs) }
}

private func makeRunner(_ settings: Settings = Settings()) -> (Runner, FakeServices) {
    let services = FakeServices()
    let engine = Engine(randomSeconds: { $0.lowerBound })
    return (Runner(engine: engine, services: services, settings: settings), services)
}

@discardableResult
private func run(_ runner: Runner, _ services: FakeServices, secs: Int) -> Snapshot {
    var last: Snapshot?
    for _ in 0..<secs {
        services.nowMs += 1_000
        last = runner.tick()
    }
    return last!
}

@Suite struct RunnerTests {
    @Test func performIsCalledOnlyWhenTheEngineActs() {
        let (runner, services) = makeRunner()
        run(runner, services, secs: 59)
        #expect(services.performCount == 0)
        let snapshot = run(runner, services, secs: 1)
        #expect(services.performCount == 1)
        #expect(snapshot.status == .keepingAlive)
    }

    @Test func permissionRemovedWhileKeepingAliveStopsInputWithinOneTick() {
        let (runner, services) = makeRunner()
        run(runner, services, secs: 60)
        #expect(services.performCount == 1)

        services.hasPermission = false
        let snapshot = run(runner, services, secs: 1)
        #expect(snapshot.status == .permissionMissing)
        run(runner, services, secs: 300)
        #expect(services.performCount == 1)
    }

    @Test func interruptedActionCountsAsTheUserReturning() {
        let (runner, services) = makeRunner()
        services.actionsComplete = false
        run(runner, services, secs: 60)
        #expect(services.performCount == 1)

        let snapshot = run(runner, services, secs: 1)
        #expect(snapshot.status == .userActive)
        #expect(snapshot.lastActionMinute == nil)
    }

    @Test func completedActionRecordsTheMinute() {
        let (runner, services) = makeRunner()
        services.localTime = LocalTime(weekday: 1, minuteOfDay: 10 * 60 + 42)
        #expect(run(runner, services, secs: 59).lastActionMinute == nil)
        #expect(run(runner, services, secs: 1).lastActionMinute == 10 * 60 + 42)
    }

    @Test func completedActionKeepsTheUserCountedAsAway() {
        let (runner, services) = makeRunner()
        run(runner, services, secs: 60)
        let snapshot = run(runner, services, secs: 10)
        #expect(snapshot.status == .keepingAlive)
        #expect(snapshot.userIdleMs == 70_000)
    }

    @Test func togglePauseStopsAndResumes() {
        let (runner, services) = makeRunner()
        runner.togglePause()
        let paused = run(runner, services, secs: 120)
        #expect(paused.status == .paused)
        #expect(paused.isPaused)
        #expect(services.performCount == 0)

        runner.togglePause()
        let resumed = run(runner, services, secs: 1)
        #expect(!resumed.isPaused)
        #expect(services.performCount == 1)
    }

    @Test func timedPauseEndsAfterAnHourOfClockTime() {
        let (runner, services) = makeRunner()
        runner.pauseForAnHour()
        #expect(run(runner, services, secs: 1).status == .pausedUntil)

        // The Mac sleeps: two hours pass on the clock with no ticks in between.
        services.nowMs += 2 * 3_600_000
        let snapshot = runner.tick()
        #expect(!snapshot.isPaused)
        #expect(snapshot.pauseEndMinute == nil)
    }

    @Test func pauseForAnHourReportsTheEndMinute() {
        let (runner, services) = makeRunner()
        services.localTime = LocalTime(weekday: 1, minuteOfDay: 23 * 60 + 30)
        runner.pauseForAnHour()
        let snapshot = run(runner, services, secs: 1)
        #expect(snapshot.status == .pausedUntil)
        #expect(snapshot.pauseEndMinute == 30)
    }

    @Test func manualPauseHasNoEndMinute() {
        let (runner, services) = makeRunner()
        runner.pauseForAnHour()
        runner.togglePause()
        runner.togglePause()
        #expect(run(runner, services, secs: 1).pauseEndMinute == nil)
    }

    @Test func holdFollowsStatusOnEveryTick() {
        let (runner, services) = makeRunner()
        run(runner, services, secs: 1)
        #expect(services.held.last == KeepAwake(system: true, display: true))

        runner.togglePause()
        run(runner, services, secs: 1)
        #expect(services.held.last == KeepAwake(system: false, display: false))
        #expect(services.held.count == 2)
    }

    @Test func changedSettingsTakeEffectOnTheNextTick() {
        let (runner, services) = makeRunner()
        run(runner, services, secs: 10)
        runner.settings.idleThresholdSecs = 5
        run(runner, services, secs: 1)
        #expect(services.performCount == 1)
    }
}
