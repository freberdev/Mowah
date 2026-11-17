import SwiftUI

@main
struct MowahApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Image(systemName: "cursorarrow")
        }
        .menuBarExtraStyle(.menu)
    }
}
