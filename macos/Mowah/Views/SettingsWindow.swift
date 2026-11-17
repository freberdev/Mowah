import AppKit
import SwiftUI

/// The settings window. A menu bar app has no window of its own, and it does not
/// come to the front by itself, so the window is created and raised by hand.
@MainActor
final class SettingsWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show(model: AppModel) {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
            window.title = "Mowah"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // A field takes its value when it loses the focus. Closing the window or
    // switching to another app does not move the focus on a Mac, so without this
    // a number that was typed last would be shown but never used.
    func windowWillClose(_ notification: Notification) {
        window?.makeFirstResponder(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        window?.makeFirstResponder(nil)
    }
}
