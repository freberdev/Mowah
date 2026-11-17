import AppKit
import CoreGraphics
import MowahCore

/// Produces harmless input. Only called when the user has been away, and only
/// works with the Accessibility permission; without it macOS drops the events.
struct InputSender {
    private static let stepPause: useconds_t = 16_000

    /// Performs one round of activity. Returns false if the user took over the mouse.
    func perform(_ settings: Settings) -> Bool {
        switch settings.method {
        case .invisible:
            sendInvisibleEvent()
        case .visibleMove:
            guard drawCircle(diameter: settings.circleDiameter) else {
                // The user grabbed the mouse mid-circle. They are back, so stop here.
                return false
            }
            // Moving the pointer by warping it is visible but is not input, so the
            // event afterwards is what actually resets the idle clocks.
            sendInvisibleEvent()
        case .key:
            sendKeyboardEvent()
        }
        if settings.leftClick, !pointerIsOverOwnWindow() {
            click()
        }
        return true
    }

    /// A mouse event at the pointer's own position. Nothing moves, but the system
    /// counts it as input and resets its idle clocks.
    private func sendInvisibleEvent() {
        guard let location = pointerLocation() else { return }
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: location, mouseButton: .left)?
            .post(tap: .cghidEventTap)
    }

    /// Draws a circle with the pointer, taking a second or two, and ends where it
    /// started. Returns false, leaving the pointer alone, as soon as something
    /// else moves it, so it never fights a returning user.
    private func drawCircle(diameter: Int) -> Bool {
        guard let origin = pointerLocation() else { return false }
        let steps = circleSteps(diameter: diameter)
        let radius = Double(diameter) / 2
        for step in 1...steps {
            let angle = 2 * Double.pi * Double(step) / Double(steps)
            let target = CGPoint(x: origin.x + radius * (1 - cos(angle)), y: origin.y + radius * sin(angle))
            warp(to: target)
            // Read back at once: at a screen edge the system puts the pointer somewhere
            // other than where it was sent, and that must not be mistaken for the user.
            let placed = pointerLocation() ?? target
            usleep(InputSender.stepPause)
            guard let actual = pointerLocation(), abs(actual.x - placed.x) < 1, abs(actual.y - placed.y) < 1 else {
                return false
            }
        }
        warp(to: origin)
        return true
    }

    private func warp(to point: CGPoint) {
        CGWarpMouseCursorPosition(point)
        // After a warp macOS ignores the real mouse for a quarter of a second.
        // Re-associating ends that at once, so a user who takes the mouse is seen.
        CGAssociateMouseAndMouseCursorPosition(1)
    }

    /// A keyboard event that types nothing: it reports that no modifier key is
    /// held. A real key would be delivered to whatever program is in front. The
    /// function keys are no exception: a terminal turns F20 into characters on
    /// the command line, and F15, which the Windows app presses, raises the
    /// display brightness on a Mac.
    private func sendKeyboardEvent() {
        guard let event = CGEvent(source: nil) else { return }
        event.type = .flagsChanged
        event.flags = []
        event.post(tap: .cghidEventTap)
    }

    private func click() {
        guard let location = pointerLocation() else { return }
        for type in [CGEventType.leftMouseDown, .leftMouseUp] {
            CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: location, mouseButton: .left)?
                .post(tap: .cghidEventTap)
        }
    }

    private func pointerLocation() -> CGPoint? {
        CGEvent(source: nil)?.location
    }

    /// A click on one of Mowah's own windows, or on its menu bar icon, could
    /// change its settings or pause it, so those are skipped.
    private func pointerIsOverOwnWindow() -> Bool {
        // Input is only ever sent from the app's timer, on the main thread.
        MainActor.assumeIsolated {
            let pointer = NSEvent.mouseLocation
            return NSApp.windows.contains { $0.isVisible && $0.frame.contains(pointer) }
        }
    }
}
