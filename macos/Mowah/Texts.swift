import Foundation
import MowahCore

/// The app's texts in one language. macOS picks a language for an app when it
/// starts and keeps it, so to change language while running, Mowah looks its
/// texts up itself, in that language's folder in the app bundle.
struct Texts {
    let language: AppLanguage
    private let bundle: Bundle

    init(_ language: AppLanguage, in main: Bundle = .main) {
        self.language = language
        let folder = main.path(forResource: language.rawValue, ofType: "lproj").flatMap { Bundle(path: $0) }
        // Without the folder the whole bundle is searched, which gives the
        // language macOS picked rather than a bare key.
        bundle = folder ?? main
    }

    /// The text for a key in the string catalog.
    func callAsFunction(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    /// A text with placeholders, filled in.
    func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: self(key), locale: .current, arguments: arguments)
    }
}
