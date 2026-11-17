import AppKit
import SwiftUI

/// The menu under the icon in the menu bar.
struct MenuContent: View {
    let model: AppModel

    var body: some View {
        Text(statusLine(model.snapshot))
        Text(lastActionLine(model.snapshot))
        Divider()
        Button(pauseTitle) { model.togglePause() }
        Button("menu.pauseForAnHour") { model.pauseForAnHour() }
        if !model.hasPermission {
            Divider()
            Button("menu.grantPermission") { model.requestPermission() }
        }
        Divider()
        Button("menu.settings") { model.showSettings() }
            .keyboardShortcut(",")
        Button("menu.quit") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var pauseTitle: LocalizedStringKey {
        model.snapshot.isPaused ? "menu.resume" : "menu.pause"
    }
}
