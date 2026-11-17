import AppKit
import MowahCore
import Observation

/// What the menu and the settings window show, and the once-a-second tick behind it.
@MainActor
@Observable
final class AppModel {
    private(set) var snapshot: Snapshot
    private(set) var hasPermission: Bool
    /// Stored and handed to the runner whenever it changes.
    var settings: Settings {
        didSet {
            guard settings != oldValue else { return }
            runner.settings = settings
            store.save(settings)
        }
    }

    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored private let services: MacServices
    @ObservationIgnored private let runner: Runner
    @ObservationIgnored private var timer: Timer?

    init() {
        let store = SettingsStore(defaults: .standard)
        let settings = store.load()
        let services = MacServices()
        let runner = Runner(engine: Engine(), services: services, settings: settings)
        self.store = store
        self.services = services
        self.runner = runner
        self.settings = settings
        self.hasPermission = services.hasPermission
        self.snapshot = runner.tick()
        startTimer()
    }

    func togglePause() {
        runner.togglePause()
        tick()
    }

    func pauseForAnHour() {
        runner.pauseForAnHour()
        tick()
    }

    /// Shows the system's own question about Accessibility. That is also what
    /// puts Mowah in the list under Privacy & Security, where the user turns it on.
    func requestPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
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
