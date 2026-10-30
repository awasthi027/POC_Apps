import Foundation
import Network

struct ConnectivityStatus: Sendable, Equatable {
    enum Interface: String, Sendable { case wifi, cellular, wired, other, none }

    var isConnected: Bool
    var isExpensive: Bool
    var isConstrained: Bool
    var interface: Interface

    static let offline = ConnectivityStatus(isConnected: false, isExpensive: false, isConstrained: false, interface: .none)
    static let wifi = ConnectivityStatus(isConnected: true, isExpensive: false, isConstrained: false, interface: .wifi)
    static let cellular = ConnectivityStatus(isConnected: true, isExpensive: true, isConstrained: false, interface: .cellular)
}

/// Injectable connectivity source. `currentStatus` is synchronous (lock-protected snapshot) so event
/// enrichment on the track path never suspends.
protocol ConnectivityMonitor: Sendable {
    var currentStatus: ConnectivityStatus { get }
    func updates() -> AsyncStream<ConnectivityStatus>
    func start()
    func stop()
}

final class PathMonitorConnectivity: ConnectivityMonitor, @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "analytics.sdk.connectivity", qos: .utility)
    private let lock = NSLock()
    // Optimistic until the first path callback: an attempted upload that fails is cheap, a suppressed one is not.
    private var latest = ConnectivityStatus(isConnected: true, isExpensive: false, isConstrained: false, interface: .other)
    private var continuations: [UUID: AsyncStream<ConnectivityStatus>.Continuation] = [:]
    private var started = false

    var currentStatus: ConnectivityStatus {
        lock.lock(); defer { lock.unlock() }
        return latest
    }

    func start() {
        lock.lock()
        guard !started else { lock.unlock(); return }
        started = true
        lock.unlock()
        monitor.pathUpdateHandler = { [weak self] path in self?.handle(path) }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
        lock.lock()
        let all = continuations.values
        continuations.removeAll()
        lock.unlock()
        all.forEach { $0.finish() }
    }

    func updates() -> AsyncStream<ConnectivityStatus> {
        AsyncStream { continuation in
            let id = UUID()
            lock.lock()
            continuations[id] = continuation
            lock.unlock()
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.lock(); self.continuations[id] = nil; self.lock.unlock()
            }
        }
    }

    private func handle(_ path: NWPath) {
        let interface: ConnectivityStatus.Interface
        if path.status != .satisfied { interface = .none }
        else if path.usesInterfaceType(.wifi) { interface = .wifi }
        else if path.usesInterfaceType(.cellular) { interface = .cellular }
        else if path.usesInterfaceType(.wiredEthernet) { interface = .wired }
        else { interface = .other }
        let status = ConnectivityStatus(isConnected: path.status == .satisfied,
                                        isExpensive: path.isExpensive,
                                        isConstrained: path.isConstrained,
                                        interface: interface)
        lock.lock()
        let changed = status != latest
        latest = status
        let targets = Array(continuations.values)
        lock.unlock()
        if changed { targets.forEach { $0.yield(status) } }
    }
}
