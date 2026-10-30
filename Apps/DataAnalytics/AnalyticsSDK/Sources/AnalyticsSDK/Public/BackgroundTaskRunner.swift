import Foundation
#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif

/// Runs work inside whatever extra execution time the OS grants when the app moves to the background.
/// Best effort: the grant is short (seconds) and can be refused or revoked; correctness never depends on it
/// because events are already durable before any upload starts.
protocol BackgroundTaskRunner: Sendable {
    func run(name: String, _ work: @escaping @Sendable () async -> Void) async
}

struct ImmediateBackgroundRunner: BackgroundTaskRunner {
    func run(name: String, _ work: @escaping @Sendable () async -> Void) async { await work() }
}

#if canImport(UIKit) && !os(watchOS)
/// Uses `UIApplication.beginBackgroundTask`. Not usable from app extensions (UIApplication.shared is
/// unavailable there): extensions should set `observesAppLifecycle = false` and call `flush()` themselves.
struct UIKitBackgroundRunner: BackgroundTaskRunner {
    func run(name: String, _ work: @escaping @Sendable () async -> Void) async {
        let box = Locked<UIBackgroundTaskIdentifier>(.invalid)
        let end: @Sendable () -> Void = {
            let id = box.withLock { v -> UIBackgroundTaskIdentifier in let c = v; v = .invalid; return c }
            if id != .invalid { DispatchQueue.main.async { UIApplication.shared.endBackgroundTask(id) } }
        }
        // The expiration handler must end the task promptly or the OS terminates the app.
        let id = await MainActor.run { UIApplication.shared.beginBackgroundTask(withName: name, expirationHandler: end) }
        box.withLock { $0 = id }
        await work()
        end()
    }
}
#endif
