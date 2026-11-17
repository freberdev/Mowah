import ApplicationServices
import CoreGraphics
import Foundation
import MowahCore

/// The real macOS behind the runner.
final class MacServices: SystemServices {
    private let power = PowerAssertions()
    private let input = InputSender()
    private let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    /// The continuous clock keeps running while the Mac sleeps, so a pause for an
    /// hour ends an hour later whatever happened in between.
    var nowMs: UInt64 {
        mach_continuous_time() * UInt64(timebase.numer) / UInt64(timebase.denom) / 1_000_000
    }

    var localTime: LocalTime {
        LocalTime(date: Date(), timeZone: .current)
    }

    /// Any kind of input, from the user or sent by a program, resets this clock.
    var systemIdleMs: UInt64 {
        let anyInput = CGEventType(rawValue: ~0)!
        let seconds = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
        return UInt64(max(0, seconds) * 1_000)
    }

    var isLocked: Bool { ScreenLock.isLocked }

    /// Read every tick: the user can give or remove the permission at any time.
    var hasPermission: Bool { AXIsProcessTrusted() }

    func perform(_ settings: Settings) -> Bool {
        input.perform(settings)
    }

    func hold(_ needs: KeepAwake) {
        power.hold(needs)
    }
}
