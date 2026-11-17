import CoreGraphics
import Foundation

/// Whether the screen is locked, asked from the login session each time.
///
/// macOS also announces locking and unlocking, but it holds such announcements
/// back from an app that is not in front, and a menu bar app almost never is.
enum ScreenLock {
    static var isLocked: Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        // The key is only there while the screen is locked.
        if (session["CGSSessionScreenIsLocked"] as? Bool) == true { return true }
        // Another user has taken over the screen with fast user switching.
        if (session["kCGSSessionOnConsoleKey"] as? Bool) == false { return true }
        return false
    }
}
