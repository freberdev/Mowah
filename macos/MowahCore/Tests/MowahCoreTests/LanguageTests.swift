import Testing
@testable import MowahCore

@Suite struct LanguageTests {
    @Test func aChosenLanguageWinsOverTheSystem() {
        #expect(resolveLanguage(.swedish, preferredLocalizations: ["en"]) == .swedish)
        #expect(resolveLanguage(.english, preferredLocalizations: ["sv"]) == .english)
    }

    @Test func followingTheSystemGivesSwedishOnlyOnASwedishMac() {
        #expect(resolveLanguage(.system, preferredLocalizations: ["sv"]) == .swedish)
        #expect(resolveLanguage(.system, preferredLocalizations: ["sv-SE", "en"]) == .swedish)
        #expect(resolveLanguage(.system, preferredLocalizations: ["en", "sv"]) == .english)
        #expect(resolveLanguage(.system, preferredLocalizations: ["de"]) == .english)
        #expect(resolveLanguage(.system, preferredLocalizations: []) == .english)
    }

    @Test func theChoicesAreStoredAsShortCodes() {
        #expect(LanguageChoice.system.rawValue == "system")
        #expect(LanguageChoice.swedish.rawValue == "sv")
        #expect(LanguageChoice.english.rawValue == "en")
    }
}
