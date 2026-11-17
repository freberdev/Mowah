import AppKit
import SwiftUI

/// The menu under the icon in the menu bar.
struct MenuContent: View {
    let model: AppModel

    var body: some View {
        let texts = model.texts
        Text(statusLine(model.snapshot, texts))
        Text(lastActionLine(model.snapshot, texts))
        Divider()
        Button(model.snapshot.isPaused ? texts("menu.resume") : texts("menu.pause")) { model.togglePause() }
        Button(texts("menu.pauseForAnHour")) { model.pauseForAnHour() }
        if !model.hasPermission {
            Divider()
            Button(texts("menu.grantPermission")) { model.requestPermission() }
        }
        Divider()
        Button(texts("menu.settings")) { model.showSettings() }
            .keyboardShortcut(",")
        Button(texts("menu.quit")) { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
