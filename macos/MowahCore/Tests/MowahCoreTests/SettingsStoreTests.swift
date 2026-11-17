import Foundation
import Testing
@testable import MowahCore

@Suite struct SettingsStoreTests {
    /// Each test gets its own preferences domain, removed afterwards.
    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let name = "MowahCoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        body(defaults)
    }

    @Test func emptyStoreGivesDefaultsAndIsFirstRun() {
        withDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            #expect(store.isFirstRun)
            #expect(store.load() == Settings())
        }
    }

    @Test func storeIsNoLongerFirstRunAfterSaving() {
        withDefaults { defaults in
            SettingsStore(defaults: defaults).save(Settings())
            #expect(!SettingsStore(defaults: defaults).isFirstRun)
        }
    }

    @Test func storeRoundTripPreservesEveryField() {
        withDefaults { defaults in
            var s = Settings()
            s.method = .key
            s.circleDiameter = 120
            s.idleThresholdSecs = 45
            s.intervalMinSecs = 20
            s.intervalMaxSecs = 200
            s.leftClick = true
            s.preventSleep = false
            s.keepDisplayOn = false
            s.scheduleEnabled = true
            s.scheduleStartMinute = 7 * 60 + 30
            s.scheduleEndMinute = 16 * 60 + 15
            s.language = .english
            SettingsStore(defaults: defaults).save(s)
            #expect(SettingsStore(defaults: defaults).load() == s)
        }
    }

    @Test func everyMethodSurvivesARoundTrip() {
        for method in Method.allCases {
            withDefaults { defaults in
                var s = Settings()
                s.method = method
                SettingsStore(defaults: defaults).save(s)
                #expect(SettingsStore(defaults: defaults).load().method == method)
            }
        }
    }

    @Test func languageFollowsTheSystemUntilSomethingElseIsChosen() {
        withDefaults { defaults in
            #expect(SettingsStore(defaults: defaults).load().language == .system)
        }
    }

    @Test func everyLanguageChoiceSurvivesARoundTrip() {
        for language in LanguageChoice.allCases {
            withDefaults { defaults in
                var s = Settings()
                s.language = language
                SettingsStore(defaults: defaults).save(s)
                #expect(SettingsStore(defaults: defaults).load().language == language)
            }
        }
    }

    @Test func languageIsStoredAsAShortCode() {
        withDefaults { defaults in
            var s = Settings()
            s.language = .swedish
            SettingsStore(defaults: defaults).save(s)
            #expect(defaults.string(forKey: "language") == "sv")
        }
    }

    @Test func unreadableStoredLanguageFollowsTheSystem() {
        withDefaults { defaults in
            defaults.set("klingon", forKey: "language")
            #expect(SettingsStore(defaults: defaults).load().language == .system)
            defaults.set(42, forKey: "language")
            #expect(SettingsStore(defaults: defaults).load().language == .system)
        }
    }

    @Test func settingsSavedBeforeTheLanguageChoiceExistedKeepTheirValues() {
        withDefaults { defaults in
            defaults.set("key", forKey: "method")
            defaults.set(true, forKey: "left_click")
            let s = SettingsStore(defaults: defaults).load()
            #expect(s.language == .system)
            #expect(s.method == .key)
            #expect(s.leftClick)
        }
    }

    @Test func outOfRangeStoredValuesAreClamped() {
        withDefaults { defaults in
            defaults.set(0, forKey: "idle_threshold_secs")
            defaults.set(99_999, forKey: "circle_diameter_px")
            defaults.set(9999, forKey: "interval_min_secs")
            defaults.set(1, forKey: "interval_max_secs")
            let s = SettingsStore(defaults: defaults).load()
            #expect(s.idleThresholdSecs == 5)
            #expect(s.circleDiameter == 1000)
            #expect(s.intervalMinSecs == 240)
            #expect(s.intervalMaxSecs == 240)
        }
    }

    @Test func unknownStoredMethodFallsBackToInvisible() {
        withDefaults { defaults in
            defaults.set("teleport", forKey: "method")
            #expect(SettingsStore(defaults: defaults).load().method == .invisible)
        }
    }

    @Test func garbageStoredValuesAreIgnored() {
        withDefaults { defaults in
            defaults.set("abc", forKey: "idle_threshold_secs")
            defaults.set("25:99", forKey: "schedule_start")
            defaults.set(12, forKey: "schedule_end")
            defaults.set(true, forKey: "left_click")
            defaults.set(1, forKey: "unknown")
            var expected = Settings()
            expected.leftClick = true
            #expect(SettingsStore(defaults: defaults).load() == expected)
        }
    }

    @Test func storedValuesUseTheDocumentedKeysAndTimeFormat() {
        withDefaults { defaults in
            var s = Settings()
            s.method = .visibleMove
            s.scheduleStartMinute = 7 * 60 + 30
            SettingsStore(defaults: defaults).save(s)
            #expect(defaults.string(forKey: "method") == "visible_move")
            #expect(defaults.string(forKey: "schedule_start") == "07:30")
            #expect(defaults.string(forKey: "schedule_end") == "17:00")
            #expect(defaults.integer(forKey: "circle_diameter_px") == 300)
            #expect(defaults.object(forKey: "keep_display_on") as? Bool == true)
        }
    }
}
