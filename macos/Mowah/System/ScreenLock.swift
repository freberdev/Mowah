import CoreGraphics
import Foundation
import os

/// Knows whether the screen is locked. macOS announces locking and unlocking
/// but has no call to ask afterwards, so the state is kept here.
final class ScreenLock {
    private let locked: OSAllocatedUnfairLock<Bool>
    private let observers: [NSObjectProtocol]

    init() {
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        let lockedNow = (session?["CGSSessionScreenIsLocked"] as? Bool) ?? false
        let locked = OSAllocatedUnfairLock(initialState: lockedNow)
        self.locked = locked

        let center = DistributedNotificationCenter.default()
        func observe(_ name: String, sets value: Bool) -> NSObjectProtocol {
            center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { _ in
                locked.withLock { $0 = value }
            }
        }
        observers = [
            observe("com.apple.screenIsLocked", sets: true),
            observe("com.apple.screenIsUnlocked", sets: false),
        ]
    }

    var isLocked: Bool { locked.withLock { $0 } }

    deinit {
        observers.forEach(DistributedNotificationCenter.default().removeObserver)
    }
}
