import SwiftUI

@main
struct MowahApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            // The label is not shown; it is what VoiceOver reads instead of the
            // name of the image file.
            Image(model.menuBarIcon, label: Text(verbatim: "Mowah"))
        }
        .menuBarExtraStyle(.menu)
    }
}
