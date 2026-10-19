//
//  NetworkHealthMonitor.swift
//  DeviceHealthLearning
//
//  Ported from TelemetrySDK NetworkInformationProvider + NetworkMonitor.
//

import Foundation
import Network
import Observation

// A network event, equivalent to what the SDK posts to its data handler.
struct NetworkEvent: Identifiable {
    enum Kind: String {
        case network_enablement
        case network_change
    }

    let id = UUID()
    let kind: Kind
    let detail: String
    let date = Date()
}

@Observable
final class NetworkHealthMonitor {
    // SDK: TelemetrySDKConstants.NETWORK_CHANGE_DELAY_NANO
    private static let networkChangeDelay: Duration = .seconds(5)
    private static let pingInterval: Duration = .seconds(5 * 60)

    private(set) var hasInternetAccess = false
    private(set) var interfaceType: NWInterface.InterfaceType = .other
    private(set) var vpnConnected: Bool?
    private(set) var ipAddress: String?
    private(set) var mobileNetworkType: String?
    private(set) var lastResult: NetworkStatResult?
    private(set) var isMeasuring = false
    private(set) var speedResult: NetworkSpeedResult?
    private(set) var isTestingSpeed = false
    private(set) var events: [NetworkEvent] = []

    private var monitor: NWPathMonitor?
    private var initialState = true
    private var lastReportedType: NWInterface.InterfaceType?
    private var reportDelayTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?

    // MARK: - Derived attributes

    var connectionType: String { interfaceType.name }

    // nil when there is no interface, like the SDK `wifi_on` attribute.
    var isWifiConnected: Bool? { interfaceType == .other ? nil : interfaceType == .wifi }

    var isMobileDataConnected: Bool { interfaceType == .cellular }

    // SDK only returns results younger than 5 minutes; stale results trigger a new measurement.
    private var freshResult: NetworkStatResult? { lastResult?.isFresh == true ? lastResult : nil }
    var latency: Float? { freshResult?.latency }
    var jitter: Float? { freshResult?.jitter }
    var packetLoss: Float? { freshResult?.packetLoss }
    // True once a probe set has finished, even if every probe failed.
    var hasMeasuredLatency: Bool { freshResult != nil }

    var downloadSpeedMbps: Float? { speedResult?.downloadMbps }
    var uploadSpeedMbps: Float? { speedResult?.uploadMbps }

    // MARK: - Lifecycle (SDK: startMonitoring / stopMonitoring)

    func startObserving() {
        guard monitor == nil else { return }

        // A cancelled NWPathMonitor cannot be restarted, so a new one is created each time.
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in self?.handle(path: path) }
        }
        monitor.start(queue: DispatchQueue(label: "DeviceHealthLearning.NetworkMonitor"))
        self.monitor = monitor

        // Repeat the latency/jitter measurement every 5 minutes.
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.pingInterval)
                await self?.startNetworkStats()
            }
        }
    }

    func stopObserving() {
        monitor?.cancel()
        monitor = nil
        pingTask?.cancel()
        pingTask = nil
        reportDelayTask?.cancel()
        reportDelayTask = nil
        initialState = true
    }

    func refresh() {
        vpnConnected = VPNMonitor.isActive()
        ipAddress = NetworkAdapter.ipAddress
        mobileNetworkType = MobileNetworkInfo.fetchMobileNetworkTypes()
    }

    // MARK: - Path updates (SDK: pathUpdateHandler)

    private func handle(path: NWPath) {
        let currentInternetAccess = path.status == .satisfied

        if currentInternetAccess != hasInternetAccess {
            // Enablement is reported against the interface in use before the change.
            post(.network_enablement, detail: "\(interfaceType.name) enabled = \(currentInternetAccess)")
            hasInternetAccess = currentInternetAccess
            Task { await startNetworkStats() }
            // First connection after launch also gets a speed test.
            if currentInternetAccess && speedResult == nil {
                Task { await startSpeedTest() }
            }
        }

        // Only one interface should be in use at a time.
        let newInterfaceType = path.availableInterfaces.first { path.usesInterfaceType($0.type) }?.type ?? .other
        if newInterfaceType != interfaceType {
            connectionTypeChanged(to: newInterfaceType, from: interfaceType)
            interfaceType = newInterfaceType
        }

        refresh()
    }

    // MARK: - network_change debouncing (SDK: connectionTypeChanged)

    private func connectionTypeChanged(to: NWInterface.InterfaceType, from: NWInterface.InterfaceType) {
        // The first callback is the OS reporting the starting state, not a change.
        guard !initialState else {
            initialState = false
            lastReportedType = to
            return
        }

        if !Self.changeRequiresDelay(to: to, from: from) {
            // Reportable immediately; supersedes any pending delayed report.
            reportDelayTask?.cancel()
            reportDelayTask = nil
            postNetworkChange(to: to)
            return
        }

        // Keep the first pending delay if another delay-worthy change arrives meanwhile.
        if let task = reportDelayTask, !task.isCancelled { return }

        // Wi-Fi 1 -> Wi-Fi 2 is signalled as wifi -> other/cellular -> wifi. The delay collapses that into one change.
        reportDelayTask = Task { [weak self] in
            try? await Task.sleep(for: Self.networkChangeDelay)
            guard !Task.isCancelled, let self else { return }
            self.postNetworkChange(to: self.interfaceType)
            self.reportDelayTask = nil
        }
    }

    static func changeRequiresDelay(to: NWInterface.InterfaceType, from: NWInterface.InterfaceType) -> Bool {
        // A disconnect (.other -> .other is not one).
        if to == .other && from != .other { return true }
        // Wi-Fi to Wi-Fi with cellular available passes through cellular first.
        if to == .cellular && from == .wifi { return true }
        return false
    }

    private func postNetworkChange(to: NWInterface.InterfaceType) {
        let from = lastReportedType?.name ?? "unknown"
        lastReportedType = to
        post(.network_change, detail: "\(from) → \(to.name)")
    }

    private func post(_ kind: NetworkEvent.Kind, detail: String) {
        events.insert(NetworkEvent(kind: kind, detail: detail), at: 0)
    }

    // MARK: - Latency / jitter (SDK: startNetworkStats)

    func startNetworkStats() async {
        guard !isMeasuring else { return }

        // Starting a new measurement clears the old result.
        lastResult = nil
        guard hasInternetAccess else { return }

        isMeasuring = true
        lastResult = await LatencyProbe.measure()
        isMeasuring = false
    }

    // MARK: - Speed test (SDK: NetworkSpeedSampler)

    // Moves up to a few tens of MB, so it only runs on start and manual refresh, not on a timer.
    func startSpeedTest() async {
        guard !isTestingSpeed else { return }

        guard hasInternetAccess else {
            speedResult = NetworkSpeedResult(downloadMbps: nil, uploadMbps: nil, timestamp: Date())
            return
        }

        isTestingSpeed = true
        speedResult = await NetworkSpeedTest.measure()
        isTestingSpeed = false
    }
}
