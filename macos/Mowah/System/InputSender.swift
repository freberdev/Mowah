import CoreGraphics
import MowahCore

/// Produces harmless input. Only called when the user has been away, and only
/// works with the Accessibility permission; without it macOS drops the events.
struct InputSender {
    /// Performs one round of activity. Returns false if the user took over the mouse.
    func perform(_ settings: Settings) -> Bool {
        sendInvisibleEvent()
        return true
    }

    /// A mouse event at the pointer's own position. Nothing moves, but the system
    /// counts it as input and resets its idle clocks.
    private func sendInvisibleEvent() {
        guard let location = CGEvent(source: nil)?.location else { return }
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: location, mouseButton: .left)?
            .post(tap: .cghidEventTap)
    }
}
