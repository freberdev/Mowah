/// What the user has chosen for the language of the menu and the settings window.
public enum LanguageChoice: String, CaseIterable, Sendable {
    /// Swedish when the Mac is in Swedish, otherwise English.
    case system
    case swedish = "sv"
    case english = "en"
}

/// The languages Mowah can be shown in. The raw value names the language's
/// folder in the app bundle.
public enum AppLanguage: String, Sendable {
    case swedish = "sv"
    case english = "en"
}

/// A chosen language is used as it is. Following the system goes by the first of
/// `preferredLocalizations`, which is the language macOS itself would have picked
/// for the app: Swedish if that is Swedish, and English for everything else.
public func resolveLanguage(_ choice: LanguageChoice, preferredLocalizations: [String]) -> AppLanguage {
    switch choice {
    case .swedish: return .swedish
    case .english: return .english
    case .system:
        let first = preferredLocalizations.first?.lowercased() ?? ""
        return first == "sv" || first.hasPrefix("sv-") || first.hasPrefix("sv_") ? .swedish : .english
    }
}
