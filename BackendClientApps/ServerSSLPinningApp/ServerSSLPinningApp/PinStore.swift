import Combine
import Foundation

/// Thread-safe store of SSL pins keyed by host.
/// Pins are strings in `sha256/<base64>` format (certificate or public-key pins).
final class PinStore: ObservableObject, @unchecked Sendable {
    static let shared = PinStore()

    private let lock = NSLock()
    private var pinsByHost: [String: Set<String>] = [:]

    /// Published snapshot for SwiftUI (host -> sorted pins). Updated on the main thread.
    @Published private(set) var snapshot: [String: [String]] = [:]

    init() {}

    // MARK: - Reads (used by the pinning delegate, possibly off the main thread)

    func pins(forHost host: String) -> Set<String> {
        lock.lock(); defer { lock.unlock() }
        return pinsByHost[host.lowercased()] ?? []
    }

    func hasPins(forHost host: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return !(pinsByHost[host.lowercased()]?.isEmpty ?? true)
    }

    func allHosts() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return Array(pinsByHost.keys)
    }

    // MARK: - Writes

    /// Replace all pins for a host.
    func setPins(_ pins: Set<String>, forHost host: String) {
        mutate { $0[host.lowercased()] = pins }
    }

    /// Merge new pins into the existing set for a host.
    func addPins(_ pins: [String], forHost host: String) {
        let key = host.lowercased()
        mutate {
            var set = $0[key] ?? []
            set.formUnion(pins)
            $0[key] = set
        }
    }

    func removePins(forHost host: String) {
        mutate { $0[host.lowercased()] = nil }
    }

    // MARK: - Internal

    private func mutate(_ block: (inout [String: Set<String>]) -> Void) {
        lock.lock()
        block(&pinsByHost)
        let snap = pinsByHost.mapValues { Array($0).sorted() }
        lock.unlock()
        publish(snap)
    }

    private func publish(_ snap: [String: [String]]) {
        if Thread.isMainThread {
            snapshot = snap
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.snapshot = snap
            }
        }
    }
}

