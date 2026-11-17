import ServiceManagement

/// Starting at login through the system's own login items, so Mowah shows up
/// under General > Login Items where the user can also turn it off.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Returns what is actually the case afterwards; macOS may refuse.
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Nothing to do about it here; the checkbox shows the real state.
        }
        return isEnabled
    }
}
