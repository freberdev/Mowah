import AppKit
import MowahCore
import Observation

/// What the menu and the settings window show, and the once-a-second tick behind it.
@MainActor
@Observable
final class AppModel {
    private(set) var snapshot: Snapshot
    private(set) var hasPermission: Bool
    /// Stored and handed to the runner whenever it changes. Values outside
    /// their limits are corrected first, so the window always shows what applies.
    var settings: Settings {
        didSet {
            let corrected = settings.normalized()
            guard corrected == settings else {
                settings = corrected
                return
            }
            guard settings != oldValue else { return }
            runner.settings = settings
            store.save(settings)
        }
    }
    /// Shows what macOS says, which is not always what was asked for.
    var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            let actual = LoginItem.setEnabled(launchAtLogin)
            if actual != launchAtLogin { launchAtLogin = actual }
        }
    }

    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored private let services: MacServices
    @ObservationIgnored private let runner: Runner
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let settingsWindow = SettingsWindow()

    init() {
        let store = SettingsStore(defaults: .standard)
        let isFirstRun = store.isFirstRun
        let settings = store.load()
        let services = MacServices()
        let runner = Runner(engine: Engine(), services: services, settings: settings)
        self.store = store
        self.services = services
        self.runner = runner
        self.settings = settings
        self.launchAtLogin = LoginItem.isEnabled
        self.hasPermission = services.hasPermission
        self.snapshot = runner.tick()
        startTimer()

        if isFirstRun {
            store.save(settings)
            // The very first start opens the window, so the permission is seen at
            // once. It has to wait until the app has finished launching.
            DispatchQueue.main.async { [weak self] in self?.showSettings() }
        }
    }

    /// The icon tells the state at a glance: plain when on duty, fainter when
    /// resting, and with a dot when Mowah cannot work without the user's help.
    var menuBarIcon: String {
        switch snapshot.status {
        case .permissionMissing: "MenuBarIconAttention"
        case .userActive, .keepingAlive: "MenuBarIcon"
        case .paused, .pausedUntil, .locked, .outsideSchedule: "MenuBarIconResting"
        }
    }

    func showSettings() {
        settingsWindow.show(model: self)
    }

    func togglePause() {
        runner.togglePause()
        tick()
    }

    func pauseForAnHour() {
        runner.pauseForAnHour()
        tick()
    }

    /// Asks for the Accessibility permission. The system's own question is what
    /// puts Mowah in the list under Privacy & Security, but macOS shows it only
    /// once, so the list itself is opened as well.
    func requestPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let list = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(list)
        }
    }

    private func tick() {
        snapshot = runner.tick()
        hasPermission = services.hasPermission
    }

    private func startTimer() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            // The timer is scheduled on the main run loop below.
            MainActor.assumeIsolated { self?.tick() }
        }
        // Common modes, so the tick keeps running while a menu is open.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
