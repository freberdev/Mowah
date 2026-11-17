import Foundation
import IOKit.pwr_mgt
import MowahCore

/// Asks macOS to stay awake, the way a video player does. The requests show up
/// in `pmset -g assertions` and disappear when the app quits.
final class PowerAssertions {
    private var systemAssertion: IOPMAssertionID = 0
    private var displayAssertion: IOPMAssertionID = 0

    func hold(_ needs: KeepAwake) {
        set(&systemAssertion, wanted: needs.system, type: kIOPMAssertionTypePreventUserIdleSystemSleep)
        set(&displayAssertion, wanted: needs.display, type: kIOPMAssertionTypePreventUserIdleDisplaySleep)
    }

    /// Creates or releases one request, and does nothing when it is already as wanted.
    private func set(_ assertion: inout IOPMAssertionID, wanted: Bool, type: String) {
        if wanted, assertion == 0 {
            var created: IOPMAssertionID = 0
            let reason = "Mowah is keeping the Mac awake" as CFString
            let result = IOPMAssertionCreateWithName(type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), reason, &created)
            // On failure the id stays 0, so the next tick tries again.
            if result == kIOReturnSuccess { assertion = created }
        } else if !wanted, assertion != 0 {
            IOPMAssertionRelease(assertion)
            assertion = 0
        }
    }
}
