import Testing
@testable import MowahCore

private let mondayNoon = LocalTime(weekday: 1, minuteOfDay: 12 * 60)
private let saturdayNoon = LocalTime(weekday: 6, minuteOfDay: 12 * 60)

/// A small deterministic generator, so a test that uses a "seed" is repeatable.
private func seededRandom(_ seed: UInt64) -> (ClosedRange<Int>) -> Int {
    var state = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return { range in
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int((state >> 33) % span)
    }
}

/// Drives the engine the way the app does: one tick per second, and every action
/// the engine asks for shows up as fresh system input shortly after.
private final class Sim {
    var engine: Engine
    var settings: Settings
    var nowMs: UInt64 = 1_000_000
    var lastInputMs: UInt64 = 1_000_000
    var local = mondayNoon
    var locked = false
    var hasPermission = true
    var actionTimes: [UInt64] = []

    init(_ settings: Settings = Settings(), seed: UInt64 = 1) {
        self.settings = settings
        self.engine = Engine(randomSeconds: seededRandom(seed))
    }

    func userInput() { lastInputMs = nowMs }

    @discardableResult func tick() -> Outcome {
        let idle = nowMs >= lastInputMs ? nowMs - lastInputMs : 0
        let outcome = engine.tick(
            settings,
            TickInput(nowMs: nowMs, systemIdleMs: idle, local: local, locked: locked, hasPermission: hasPermission)
        )
        if outcome.act {
            actionTimes.append(nowMs)
            lastInputMs = nowMs + 15
        }
        return outcome
    }

    /// Advances one second at a time, ticking after each step. Returns the last outcome.
    @discardableResult func runSecs(_ secs: Int) -> Outcome {
        var last: Outcome?
        for _ in 0..<secs {
            nowMs += 1_000
            last = tick()
        }
        return last!
    }
}

private func fixedInterval(_ secs: Int) -> Settings {
    var s = Settings()
    s.intervalMinSecs = secs
    s.intervalMaxSecs = secs
    return s
}

private func randomInterval() -> Settings {
    var s = Settings()
    s.intervalMinSecs = 30
    s.intervalMaxSecs = 90
    return s
}

private var scheduled: Settings {
    var s = Settings()
    s.scheduleEnabled = true
    return s
}

@Suite struct EngineTests {
    @Test func doesNothingWhileTheUserIsWorking() {
        let sim = Sim()
        for _ in 0..<600 {
            sim.nowMs += 1_000
            sim.userInput()
            #expect(sim.tick().status == .userActive)
        }
        #expect(sim.actionTimes.isEmpty)
    }

    @Test func staysQuietUntilTheIdleThresholdIsReached() {
        let sim = Sim()
        #expect(sim.runSecs(59).status == .userActive)
        #expect(sim.actionTimes.isEmpty)
    }

    @Test func actsAsSoonAsTheUserHasBeenIdleForTheThreshold() {
        let sim = Sim()
        let outcome = sim.runSecs(60)
        #expect(outcome.status == .keepingAlive)
        #expect(outcome.act)
        #expect(sim.actionTimes == [1_060_000])
    }

    @Test func repeatsAtTheConfiguredIntervalWhileTheUserIsAway() {
        let sim = Sim(fixedInterval(30))
        sim.runSecs(60 + 95)
        #expect(sim.actionTimes == [1_060_000, 1_090_000, 1_120_000, 1_150_000])
    }

    @Test func itsOwnInputDoesNotCountAsTheUserReturning() {
        let sim = Sim(fixedInterval(30))
        let outcome = sim.runSecs(300)
        #expect(outcome.status == .keepingAlive)
        #expect(outcome.userIdleMs == 300_000)
    }

    @Test func randomIntervalStaysWithinTheConfiguredRange() {
        for seed in UInt64(1)...20 {
            let sim = Sim(randomInterval(), seed: seed)
            sim.runSecs(3_600)
            #expect(sim.actionTimes.count > 10)
            for (earlier, later) in zip(sim.actionTimes, sim.actionTimes.dropFirst()) {
                #expect((30_000...90_000).contains(later - earlier), "seed \(seed): gap \(later - earlier) ms")
            }
        }
    }

    @Test func randomIntervalActuallyVaries() {
        let sim = Sim(randomInterval())
        sim.runSecs(3_600)
        let gaps = zip(sim.actionTimes, sim.actionTimes.dropFirst()).map { $1 - $0 }
        #expect(gaps.contains { $0 != gaps[0] })
    }

    @Test func stopsTheMomentTheUserComesBack() {
        let sim = Sim(fixedInterval(30))
        sim.runSecs(70)
        #expect(sim.actionTimes.count == 1)

        sim.nowMs += 5_000
        sim.userInput()
        let outcome = sim.tick()
        #expect(outcome.status == .userActive)
        #expect(outcome.userIdleMs == 0)

        sim.runSecs(59)
        #expect(sim.actionTimes.count == 1, "must wait a full idle threshold again")
        sim.runSecs(1)
        #expect(sim.actionTimes.count == 2)
    }

    @Test func userInputLongAfterAnActionIsRecognisedAsTheUser() {
        let sim = Sim(fixedInterval(200))
        sim.runSecs(60)
        sim.nowMs += Engine.ownInputWindowMs + 1_000
        sim.userInput()
        #expect(sim.tick().status == .userActive)
    }

    @Test func userInputTwoSecondsAfterAnActionIsTheUser() {
        let sim = Sim(fixedInterval(200))
        sim.runSecs(60)
        sim.nowMs += 2_000
        sim.userInput()
        #expect(sim.tick().status == .userActive)
    }

    @Test func ownInputWindowIsOneAndAHalfSeconds() {
        #expect(Engine.ownInputWindowMs == 1_500)
    }

    @Test func inputAtTheEndOfASlowActionIsStillItsOwn() {
        let sim = Sim(fixedInterval(200))
        sim.runSecs(60)
        let actedAt = sim.nowMs
        // A visible pointer movement that takes 1.4 s and ends with the real input.
        sim.nowMs = actedAt + 1_400
        sim.lastInputMs = sim.nowMs
        sim.engine.actionFinished(nowMs: sim.nowMs)

        let outcome = sim.runSecs(2)
        #expect(outcome.status == .keepingAlive)
        #expect(outcome.userIdleMs == 63_400)
    }

    @Test func inputWellAfterASlowActionFinishedIsTheUser() {
        let sim = Sim(fixedInterval(200))
        sim.runSecs(60)
        let actedAt = sim.nowMs
        sim.engine.actionFinished(nowMs: actedAt + 1_400)
        sim.nowMs = actedAt + 1_400 + Engine.ownInputWindowMs + 500
        sim.userInput()
        #expect(sim.tick().status == .userActive)
    }

    @Test func grabbingTheMouseDuringAnActionCountsAsTheUserReturning() {
        let sim = Sim(fixedInterval(200))
        sim.runSecs(60)
        let actedAt = sim.nowMs
        // The user moves the mouse 200 ms into the action, which then stops.
        sim.lastInputMs = actedAt + 200
        sim.engine.userInterrupted(nowMs: actedAt + 300)

        let outcome = sim.runSecs(1)
        #expect(outcome.status == .userActive)
        #expect(outcome.userIdleMs <= 1_000, "idle was \(outcome.userIdleMs) ms")
    }

    @Test func idleTimeFromBeforeStartupCounts() {
        let sim = Sim()
        sim.lastInputMs = sim.nowMs - 120_000
        let outcome = sim.tick()
        #expect(outcome.act)
        #expect(outcome.userIdleMs == 120_000)
    }

    @Test func manualPauseBlocksActionsUntilResumed() {
        let sim = Sim()
        sim.engine.pause()
        #expect(sim.engine.isPaused)
        #expect(sim.runSecs(600).status == .paused)
        #expect(sim.actionTimes.isEmpty)

        sim.engine.resume()
        #expect(!sim.engine.isPaused)
        #expect(sim.runSecs(1).act, "the user is long idle, so it acts right after resuming")
    }

    @Test func timedPauseEndsByItself() {
        let sim = Sim()
        sim.engine.pause(untilMs: sim.nowMs + 3_600_000)
        #expect(sim.runSecs(3_599).status == .pausedUntil)
        #expect(sim.engine.isPaused)
        #expect(sim.actionTimes.isEmpty)

        let outcome = sim.runSecs(1)
        #expect(outcome.status == .keepingAlive)
        #expect(outcome.act)
        #expect(!sim.engine.isPaused)
    }

    @Test func lockedSessionBlocksActions() {
        let sim = Sim()
        sim.locked = true
        #expect(sim.runSecs(600).status == .locked)
        #expect(sim.actionTimes.isEmpty)
    }

    @Test func nothingHappensOutsideTheSchedule() {
        let sim = Sim(scheduled)
        sim.local = saturdayNoon
        #expect(sim.runSecs(600).status == .outsideSchedule)
        #expect(sim.actionTimes.isEmpty)

        sim.local = mondayNoon
        #expect(sim.runSecs(1).act)
    }

    @Test func userActivityIsStillTrackedWhilePaused() {
        let sim = Sim()
        sim.engine.pause()
        sim.runSecs(600)
        sim.userInput()
        sim.runSecs(10)
        sim.engine.resume()
        let outcome = sim.runSecs(1)
        #expect(outcome.status == .userActive)
        #expect(outcome.userIdleMs == 11_000)
        #expect(sim.actionTimes.isEmpty)
    }

    @Test func pauseReportsPausedEvenWhenAlsoLockedOrOffSchedule() {
        let sim = Sim(scheduled)
        sim.local = saturdayNoon
        sim.locked = true
        sim.engine.pause()
        #expect(sim.runSecs(1).status == .paused)
    }

    @Test func onlyOnDutyStatusesAreArmed() {
        #expect(Status.userActive.isArmed)
        #expect(Status.keepingAlive.isArmed)
        for status in [Status.paused, .pausedUntil, .outsideSchedule, .locked, .permissionMissing] {
            #expect(!status.isArmed)
        }
    }

    // MARK: Mac only

    @Test func missingPermissionBlocksActionsAndSaysSo() {
        let sim = Sim()
        sim.hasPermission = false
        #expect(sim.runSecs(600).status == .permissionMissing)
        #expect(sim.actionTimes.isEmpty)

        sim.hasPermission = true
        #expect(sim.runSecs(1).act, "it starts as soon as the permission is given")
    }

    @Test func pauseAndLockAndScheduleOutrankMissingPermission() {
        let sim = Sim(scheduled)
        sim.hasPermission = false

        sim.local = saturdayNoon
        #expect(sim.runSecs(1).status == .outsideSchedule)
        sim.locked = true
        #expect(sim.runSecs(1).status == .locked)
        sim.engine.pause()
        #expect(sim.runSecs(1).status == .paused)
    }

    @Test func staleIdleReadingRightAfterAnActionDoesNotTriggerAnotherAction() {
        let sim = Sim(fixedInterval(5))
        let beforeAction = sim.lastInputMs
        sim.runSecs(60)
        // The idle clock lags: a quarter of a second later it still shows the old value.
        sim.lastInputMs = beforeAction
        sim.nowMs += 250
        let outcome = sim.tick()
        #expect(!outcome.act)
        #expect(outcome.status == .keepingAlive)
        #expect(sim.actionTimes.count == 1)
    }

    @Test func lateResetStampedAtTheActionIsOwnInput() {
        let sim = Sim(fixedInterval(200))
        let beforeAction = sim.lastInputMs
        sim.runSecs(60)
        let actedAt = sim.nowMs
        sim.lastInputMs = beforeAction
        sim.nowMs = actedAt + 250
        sim.tick()
        // Now the clock catches up and shows an event stamped at the action.
        sim.lastInputMs = actedAt + 10
        sim.nowMs = actedAt + 750
        let outcome = sim.tick()
        #expect(outcome.status == .keepingAlive)
        #expect(outcome.userIdleMs == 60_750)
    }

    @Test func ownInputStampedAFewMillisecondsBeforeTheActionIsStillItsOwn() {
        // The time of the last input is worked out from two readings rounded to
        // whole milliseconds, so Mowah's own event can appear to be slightly
        // earlier than the tick that sent it. Seen on a Mac on 2026-11-17.
        let sim = Sim(fixedInterval(30))
        sim.runSecs(60)
        sim.lastInputMs = sim.nowMs - 2
        let outcome = sim.runSecs(10)
        #expect(outcome.status == .keepingAlive)
        #expect(outcome.userIdleMs == 70_000)
        #expect(sim.actionTimes.count == 1)
    }

    @Test func inputClearlyBeforeTheActionIsTheUser() {
        // The idle clock lags, so real input from just before the action can show up
        // only afterwards. A third of a second is too early to be Mowah's own.
        let sim = Sim(fixedInterval(200))
        sim.runSecs(60)
        sim.lastInputMs = sim.nowMs - 300
        #expect(sim.runSecs(1).status == .userActive)
    }

    @Test func idleLongerThanTheClockValueDoesNotWrap() {
        let engine = Engine()
        let outcome = engine.tick(
            Settings(),
            TickInput(nowMs: 5_000, systemIdleMs: 9_000_000, local: mondayNoon, locked: false, hasPermission: true)
        )
        #expect(outcome.userIdleMs == 5_000)
    }
}
