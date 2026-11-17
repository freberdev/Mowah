import Testing
@testable import MowahCore

@Suite struct KeepAwakeTests {
    @Test func onDutyKeepsSystemAndDisplayAwake() {
        for status in [Status.userActive, .keepingAlive] {
            #expect(keepAwake(status: status, settings: Settings()) == KeepAwake(system: true, display: true))
        }
    }

    @Test func keepAwakeFollowsEachSettingSeparately() {
        var onlySystem = Settings()
        onlySystem.keepDisplayOn = false
        #expect(keepAwake(status: .userActive, settings: onlySystem) == KeepAwake(system: true, display: false))
        var onlyDisplay = Settings()
        onlyDisplay.preventSleep = false
        #expect(keepAwake(status: .userActive, settings: onlyDisplay) == KeepAwake(system: false, display: true))
    }

    @Test func pausedOrOffScheduleLetsTheComputerSleep() {
        for status in [Status.paused, .pausedUntil, .outsideSchedule] {
            #expect(keepAwake(status: status, settings: Settings()) == KeepAwake(system: false, display: false))
        }
    }

    @Test func lockedComputerStaysAwakeButMayTurnOffTheScreen() {
        #expect(keepAwake(status: .locked, settings: Settings()) == KeepAwake(system: true, display: false))
        var sleepAllowed = Settings()
        sleepAllowed.preventSleep = false
        #expect(keepAwake(status: .locked, settings: sleepAllowed) == KeepAwake(system: false, display: false))
    }

    @Test func missingPermissionStillKeepsTheMacAwake() {
        #expect(keepAwake(status: .permissionMissing, settings: Settings()) == KeepAwake(system: true, display: true))
        var nothing = Settings()
        nothing.preventSleep = false
        nothing.keepDisplayOn = false
        #expect(keepAwake(status: .permissionMissing, settings: nothing) == KeepAwake(system: false, display: false))
    }
}
