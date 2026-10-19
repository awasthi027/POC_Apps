//
//  BaseViewModel.swift
//  DeviceHealthLearning
//

import Foundation
import UIKit
import Observation

// Owns the battery, network and performance monitors and turns their raw values into display
// items for BaseView.
@Observable
final class BaseViewModel {
    let title = "Device Health"

    private let battery: BatteryHealthMonitor
    private let network: NetworkHealthMonitor
    private let performance: DevicePerformanceMonitor

    private(set) var restrictionReport: NetworkRestrictionReport?
    private(set) var isCheckingRestrictions = false

    init(battery: BatteryHealthMonitor = BatteryHealthMonitor(),
         network: NetworkHealthMonitor = NetworkHealthMonitor(),
         performance: DevicePerformanceMonitor = DevicePerformanceMonitor()) {
        self.battery = battery
        self.network = network
        self.performance = performance
    }

    // MARK: - Lifecycle

    func onAppear() {
        battery.startObserving()
        network.startObserving()
        performance.startObserving()
        network.refresh()
        Task { await checkRestrictions() }
    }

    func checkRestrictions() async {
        guard !isCheckingRestrictions else { return }
        isCheckingRestrictions = true
        restrictionReport = await NetworkRestrictionCheck.run()
        isCheckingRestrictions = false
    }

    func onDisappear() {
        battery.stopObserving()
        network.stopObserving()
        performance.stopObserving()
    }

    func refresh() async {
        battery.refresh()
        network.refresh()
        performance.refresh()
        // Latency and speed are independent, so run them side by side.
        async let stats: Void = network.startNetworkStats()
        async let speed: Void = network.startSpeedTest()
        async let restrictions: Void = checkRestrictions()
        _ = await (stats, speed, restrictions)
    }

    // Refreshes only the data one category's detail page shows.
    func refresh(_ category: HealthCategory) async {
        switch category {
        case .battery:
            battery.refresh()
        case .network:
            network.refresh()
            await network.startNetworkStats()
        case .networkSpeed:
            network.refresh()
            await network.startSpeedTest()
        case .networkRestrictions:
            network.refresh()
            await checkRestrictions()
        case .performance:
            performance.refresh()
        }
    }

    // MARK: - Status summary

    var batterySummary: HealthSummary {
        var status = HealthStatus.green
        var reasons: [String] = []
        let onPower = battery.pluggedType == .pluggedUSB

        if let level = battery.batteryLevel {
            // Same bands the SDK uses for critical_battery_level: >20%, 11–20%, ≤10%.
            let levelStatus: HealthStatus = level > 20 ? .green : (level > 10 ? .orange : .red)
            if levelStatus != .green {
                // Being on power reduces the risk by one step.
                status = max(status, onPower ? .orange : levelStatus)
                reasons.append(String(format: "Battery at %.0f%%%@", level, onPower ? " (charging)" : ""))
            }
        } else {
            status = max(status, .orange)
            reasons.append("Battery level unavailable")
        }

        if let rate = battery.chargeRate, rate <= Self.fastDrainPercentPerHour, !onPower {
            status = max(status, .orange)
            reasons.append(String(format: "Draining fast (%.1f %%/h)", rate))
        }

        if battery.lowPowerMode {
            status = max(status, .orange)
            reasons.append("Low Power Mode is on")
        }

        return HealthSummary(name: "Battery", status: status, reasons: reasons.isEmpty ? ["Battery is healthy"] : reasons)
    }

    // Connection quality: reachability, latency, jitter and probe loss.
    var networkSummary: HealthSummary {
        guard network.hasInternetAccess else {
            return HealthSummary(name: "Network", status: .red, reasons: ["No internet connection"])
        }

        // Until a probe set finishes, the quality is unknown. That is never reported as green.
        guard network.hasMeasuredLatency else {
            return HealthSummary(name: "Network", status: .orange,
                                 reasons: [network.isMeasuring ? "Measuring connection quality…" : "Not measured yet"])
        }

        var status = HealthStatus.green
        var reasons: [String] = []

        if let loss = network.packetLoss, loss > 0 {
            let lossStatus = Self.rate(loss * 100, orangeAbove: Self.packetLossOrangePercent,
                                       redAbove: Self.packetLossRedPercent)
            if lossStatus != .green {
                status = max(status, lossStatus)
                reasons.append(String(format: "%.0f%% of probes failed", loss * 100))
            }
        }

        if let latency = network.latency {
            let latencyStatus = Self.rate(latency, orangeAbove: Self.latencyOrangeMs, redAbove: Self.latencyRedMs)
            if latencyStatus != .green {
                status = max(status, latencyStatus)
                reasons.append(String(format: "High latency (%.0f ms)", latency))
            }
        } else {
            // Fewer than 2 probes got through: the connection is effectively unusable.
            status = .red
            reasons.append("Server unreachable")
        }

        if let jitter = network.jitter {
            let jitterStatus = Self.rate(jitter, orangeAbove: Self.jitterOrangeMs, redAbove: Self.jitterRedMs)
            if jitterStatus != .green {
                status = max(status, jitterStatus)
                reasons.append(String(format: "High jitter (%.0f ms)", jitter))
            }
        }

        if let types = network.mobileNetworkType, network.isMobileDataConnected,
           types.contains("2G") || types.contains("3G") {
            status = max(status, .orange)
            reasons.append("Slow mobile network (\(types))")
        }

        return HealthSummary(name: "Network", status: status,
                             reasons: reasons.isEmpty ? ["Connected via \(network.connectionType)"] : reasons)
    }

    // Throughput from the last speed test.
    var speedSummary: HealthSummary {
        guard network.hasInternetAccess else {
            return HealthSummary(name: "Network Speed", status: .red, reasons: ["No internet connection"])
        }

        if network.isTestingSpeed {
            return HealthSummary(name: "Network Speed", status: .orange, reasons: ["Testing speed…"])
        }

        guard network.speedResult != nil else {
            return HealthSummary(name: "Network Speed", status: .orange, reasons: ["Not tested yet. Pull to refresh."])
        }

        // Higher is better here, so the bands are inverted compared to latency.
        let download = network.downloadSpeedMbps
        let upload = network.uploadSpeedMbps
        let downloadStatus = Self.rateSpeed(download, orangeBelow: Self.downloadOrangeMbps, redBelow: Self.downloadRedMbps)
        let uploadStatus = Self.rateSpeed(upload, orangeBelow: Self.uploadOrangeMbps, redBelow: Self.uploadRedMbps)

        return HealthSummary(name: "Network Speed", status: max(downloadStatus, uploadStatus), reasons: [
            "Download: \(Self.formatMbps(download))",
            "Upload: \(Self.formatMbps(upload))",
        ])
    }

    // Whether this network blocks or tampers with traffic (proxy, TLS, QUIC).
    var restrictionsSummary: HealthSummary {
        let name = "Network Restrictions"
        if isCheckingRestrictions {
            return HealthSummary(name: name, status: .orange, reasons: ["Checking…"])
        }
        guard let report = restrictionReport else {
            return HealthSummary(name: name, status: .orange, reasons: ["Not checked yet. Pull to refresh."])
        }

        var status = HealthStatus.green
        var reasons: [String] = []

        for endpoint in report.endpoints {
            let host = endpoint.url.host() ?? endpoint.url.absoluteString
            switch (endpoint.defaultTLS.succeeded, endpoint.tls12Only.succeeded) {
            case (false, true):
                // The pattern seen when a firewall breaks on the TLS 1.3 ClientHello.
                status = .red
                reasons.append("\(host): fails with default TLS but works with TLS 1.2")
            case (false, false):
                status = .red
                reasons.append("\(host): unreachable")
            default:
                break
            }

            if Self.isInterceptionSuspected(endpoint) {
                status = max(status, .orange)
                reasons.append("\(host): TLS inspection suspected (root: \(endpoint.certificateChain.last ?? "?"))")
            }
        }

        if report.proxy.isConfigured {
            status = max(status, .orange)
            reasons.append("Proxy configured on this network")
        }

        if !report.quic.succeeded {
            // Apps normally fall back to TCP, so this is a warning, not a failure.
            status = max(status, .orange)
            reasons.append("QUIC (UDP 443) blocked")
        }

        // Informational only: a VPN that passes traffic through cleanly (no proxy/TLS
        // interception/QUIC block detected above) does not itself raise the status.
        if network.vpnConnected == true {
            reasons.append("VPN active on this device")
        }

        return HealthSummary(name: name, status: status, reasons: reasons.isEmpty ? ["No restrictions detected"] : reasons)
    }

    // Rough proxy for how loaded the device is right now: thermal throttling, system-wide memory
    // pressure, this app's own memory headroom, free storage, and the device's age/RAM class.
    // Cannot see *why* — which app, which process — only that the device (or iOS itself) is under
    // pressure; see DevicePerformanceMonitor's header comment for what is and isn't visible here.
    var performanceSummary: HealthSummary {
        var status = HealthStatus.green
        var reasons: [String] = []

        switch performance.thermalState {
        case .fair:
            status = max(status, .orange)
            reasons.append("Device is warm — may start throttling performance")
        case .serious:
            status = max(status, .red)
            reasons.append("Device is hot — performance is being throttled")
        case .critical:
            status = max(status, .red)
            reasons.append("Device is overheating — heavily throttled, may shut down")
        case .nominal:
            break
        @unknown default:
            break
        }

        switch performance.memoryPressure {
        case .warning:
            status = max(status, .orange)
            reasons.append("System memory pressure: warning — something on this device is using a lot of RAM")
        case .critical:
            status = max(status, .red)
            reasons.append("System memory pressure: critical — the device is almost out of memory")
        case .normal:
            break
        }

        if let headroom = performance.availableMemoryBeforeTerminationMB {
            let headroomStatus: HealthStatus = headroom < Self.headroomRedMB ? .red
                : (headroom < Self.headroomOrangeMB ? .orange : .green)
            if headroomStatus != .green {
                status = max(status, headroomStatus)
                reasons.append(String(format: "Only %.0f MB of memory headroom left for this app", headroom))
            }
        }

        if let free = performance.freeDiskSpaceGB {
            let diskStatus: HealthStatus = free < Self.diskRedGB ? .red : (free < Self.diskOrangeGB ? .orange : .green)
            if diskStatus != .green {
                status = max(status, diskStatus)
                reasons.append(String(format: "Low free storage (%.1f GB) — this can slow the whole device", free))
            }
        }

        if performance.memoryWarningCount > 0 {
            status = max(status, .orange)
            reasons.append("Received \(performance.memoryWarningCount) low-memory warning(s) this session")
        }

        if performance.totalMemoryGB < Self.lowRAMThresholdGB {
            status = max(status, .orange)
            reasons.append(String(format: "Low-RAM device (%.0f GB total) — background apps reload more often", performance.totalMemoryGB))
        }

        if let age = performance.deviceAgeInYears, age >= Self.oldDeviceThresholdYears {
            status = max(status, .orange)
            reasons.append("Device is \(age) years old (released \(performance.deviceReleaseYear ?? 0)) — " +
                          "older hardware can feel slower on a new iOS version")
        }

        return HealthSummary(name: "Device Performance", status: status,
                             reasons: reasons.isEmpty ? ["Device is performing normally"] : reasons)
    }

    // Assumed thresholds — not from any Apple documentation, just common-sense cut-offs.
    private static let headroomRedMB: Double = 50
    private static let headroomOrangeMB: Double = 150
    private static let diskRedGB: Double = 1
    private static let diskOrangeGB: Double = 5
    private static let lowRAMThresholdGB: Double = 3
    private static let oldDeviceThresholdYears: Int = 5

    // Worst of all areas.
    var overallStatus: HealthStatus {
        max(batterySummary.status, networkSummary.status, speedSummary.status, restrictionsSummary.status,
            performanceSummary.status)
    }

    // MARK: - Category lookup (used by BaseView's navigation and HealthDetailView)

    func summary(for category: HealthCategory) -> HealthSummary {
        switch category {
        case .battery: return batterySummary
        case .network: return networkSummary
        case .networkSpeed: return speedSummary
        case .networkRestrictions: return restrictionsSummary
        case .performance: return performanceSummary
        }
    }

    func items(for category: HealthCategory) -> [HealthItem] {
        switch category {
        case .battery: return batteryItems
        case .network: return networkItems
        case .networkSpeed: return speedItems
        case .networkRestrictions: return restrictionItems
        case .performance: return performanceItems
        }
    }

    // Events relevant to this category only. Network Speed and Restrictions don't post events.
    func events(for category: HealthCategory) -> [HealthEvent] {
        switch category {
        case .battery:
            return battery.events.map { HealthEvent(id: $0.id, name: $0.kind.rawValue, detail: $0.detail, date: $0.date) }
                .sorted { $0.date > $1.date }
        case .network:
            return network.events.map { HealthEvent(id: $0.id, name: $0.kind.rawValue, detail: $0.detail, date: $0.date) }
                .sorted { $0.date > $1.date }
        case .performance:
            return performance.events.map { HealthEvent(id: $0.id, name: $0.kind.rawValue, detail: $0.detail, date: $0.date) }
                .sorted { $0.date > $1.date }
        case .networkSpeed, .networkRestrictions:
            return []
        }
    }

    // Root names used by common TLS-inspecting firewalls / secure web gateways.
    private nonisolated static let inspectionVendorKeywords = [
        "fortinet", "fortigate", "zscaler", "palo alto", "blue coat", "bluecoat", "netskope", "forcepoint",
        "websense", "sophos", "check point", "checkpoint", "barracuda", "mcafee", "cisco umbrella", "symantec web",
    ]

    private nonisolated static func isInterceptionSuspected(_ endpoint: EndpointReport) -> Bool {
        if endpoint.trustError != nil { return true }
        let chain = endpoint.certificateChain.joined(separator: " ").lowercased()
        return inspectionVendorKeywords.contains { chain.contains($0) }
    }

    // Assumed thresholds: these are not defined by TelemetrySDK. Latency/jitter are one-way values.
    private static let fastDrainPercentPerHour: Float = -20
    private static let latencyOrangeMs: Float = 50
    private static let latencyRedMs: Float = 150
    private static let jitterOrangeMs: Float = 15
    private static let jitterRedMs: Float = 30
    private static let packetLossOrangePercent: Float = 10
    private static let packetLossRedPercent: Float = 30
    private static let downloadOrangeMbps: Float = 10
    private static let downloadRedMbps: Float = 2
    private static let uploadOrangeMbps: Float = 5
    private static let uploadRedMbps: Float = 1

    private nonisolated static func rate(_ value: Float, orangeAbove: Float, redAbove: Float) -> HealthStatus {
        value > redAbove ? .red : (value > orangeAbove ? .orange : .green)
    }

    // nil speed means nothing got through, which is the worst case.
    private nonisolated static func rateSpeed(_ mbps: Float?, orangeBelow: Float, redBelow: Float) -> HealthStatus {
        guard let mbps else { return .red }
        return mbps < redBelow ? .red : (mbps < orangeBelow ? .orange : .green)
    }

    private nonisolated static func formatMbps(_ mbps: Float?) -> String {
        mbps.map { String(format: "%.1f Mbps", $0) } ?? "failed"
    }

    // MARK: - Display data

    var batteryItems: [HealthItem] {
        [
            HealthItem(name: "battery_level", value: battery.batteryLevel.map { String(format: "%.0f%%", $0) }),
            HealthItem(name: "battery_charging_status", value: battery.chargingStatus.rawValue),
            HealthItem(name: "plugged_type", value: battery.pluggedType.rawValue),
            HealthItem(name: "battery_type", value: BatteryHealthMonitor.batteryType),
            HealthItem(name: "battery_charging_rate",
                       value: battery.chargeRate.map { String(format: "%+.2f %%/h", $0) },
                       footnote: "\(battery.sampleCount) sample(s) in last hour"),
            HealthItem(name: "battery_time_since_charging", value: battery.timeSpentOnCharger.map(Self.duration)),
            HealthItem(name: "battery_time_since_unplugged",
                       value: battery.timeSinceUnpluggedFromCharger.map(Self.duration)),
            HealthItem(name: "low_power_mode", value: battery.lowPowerMode ? "on" : "off"),
        ]
    }

    var networkItems: [HealthItem] {
        [
            HealthItem(name: "internet_available", value: String(network.hasInternetAccess)),
            HealthItem(name: "network_connectivity_type", value: network.connectionType),
            HealthItem(name: "wifi_on", value: network.isWifiConnected.map { String($0) }),
            HealthItem(name: "mobile_radio_active", value: String(network.isMobileDataConnected)),
            HealthItem(name: "mobile_network_type", value: network.mobileNetworkType),
            HealthItem(name: "vpn_connected", value: network.vpnConnected.map { String($0) }),
            HealthItem(name: "ip_address", value: network.ipAddress),
            HealthItem(name: "latency", value: network.latency.map { String(format: "%.1f ms", $0) },
                       footnote: network.isMeasuring ? "measuring…" : nil),
            HealthItem(name: "jitter", value: network.jitter.map { String(format: "%.1f ms", $0) }),
            HealthItem(name: "packet_loss", value: network.packetLoss.map { String(format: "%.0f%%", $0 * 100) }),
        ]
    }

    var speedItems: [HealthItem] {
        let footnote = network.isTestingSpeed ? "testing…"
            : network.speedResult.map { "tested \($0.timestamp.formatted(date: .omitted, time: .shortened))" }
        return [
            HealthItem(name: "network_download_speed_mbps", value: network.speedResult.map { _ in Self.formatMbps(network.downloadSpeedMbps) },
                       footnote: footnote),
            HealthItem(name: "network_upload_speed_mbps", value: network.speedResult.map { _ in Self.formatMbps(network.uploadSpeedMbps) }),
        ]
    }

    var performanceItems: [HealthItem] {
        [
            HealthItem(name: "device_model", value: performance.deviceFriendlyName ?? performance.deviceIdentifier,
                       footnote: performance.deviceFriendlyName == nil
                           ? "Unrecognized identifier — add it to DeviceModel.swift" : nil),
            HealthItem(name: "device_identifier", value: performance.deviceIdentifier),
            HealthItem(name: "device_release_year", value: performance.deviceReleaseYear.map(String.init)),
            HealthItem(name: "ios_version", value: performance.systemVersion),
            HealthItem(name: "total_ram_gb", value: String(format: "%.1f GB", performance.totalMemoryGB)),
            HealthItem(name: "cpu_cores", value: "\(performance.activeProcessorCount) active / \(performance.processorCount) total"),
            HealthItem(name: "app_memory_footprint_mb", value: performance.appMemoryFootprintMB.map { String(format: "%.0f MB", $0) }),
            HealthItem(name: "memory_headroom_before_termination_mb",
                       value: performance.availableMemoryBeforeTerminationMB.map { String(format: "%.0f MB", $0) },
                       footnote: "iOS's own estimate of how much more this app could allocate before being killed"),
            HealthItem(name: "system_memory_pressure", value: performance.memoryPressure.rawValue,
                       footnote: "System-wide signal from iOS — the closest public proxy for \"something else on " +
                                 "this device is using a lot of memory\""),
            HealthItem(name: "app_cpu_usage_percent", value: performance.appCPUUsagePercent.map { String(format: "%.0f%%", $0) },
                       footnote: "This app's own CPU use only — iOS does not expose other apps' CPU/memory use"),
            HealthItem(name: "thermal_state", value: performance.thermalState.description),
            HealthItem(name: "free_disk_space_gb", value: performance.freeDiskSpaceGB.map { String(format: "%.1f GB", $0) }),
            HealthItem(name: "total_disk_space_gb", value: performance.totalDiskSpaceGB.map { String(format: "%.1f GB", $0) }),
            HealthItem(name: "low_power_mode", value: performance.lowPowerMode ? "on" : "off"),
            HealthItem(name: "system_uptime", value: Self.duration(performance.systemUptime),
                       footnote: "Time since the device last restarted — a very long uptime can correlate with sluggishness"),
            HealthItem(name: "memory_warnings_this_session", value: String(performance.memoryWarningCount)),
            HealthItem(name: "background_app_refresh", value: Self.describe(performance.backgroundRefreshStatus),
                       footnote: "This app's own permission only — not a list of what is actually running in the background"),
        ]
    }

    private nonisolated static func describe(_ status: UIBackgroundRefreshStatus) -> String {
        switch status {
        case .available: return "available"
        case .denied: return "denied"
        case .restricted: return "restricted"
        @unknown default: return "unknown"
        }
    }

    var restrictionItems: [HealthItem] {
        guard let report = restrictionReport else {
            return [HealthItem(name: "status", value: isCheckingRestrictions ? "checking…" : nil)]
        }

        var items = [
            HealthItem(name: "vpn_active", value: network.vpnConnected.map { String($0) }),
            HealthItem(name: "proxy_http", value: report.proxy.httpProxy),
            HealthItem(name: "proxy_https", value: report.proxy.httpsProxy),
            HealthItem(name: "proxy_pac_url", value: report.proxy.pacURL),
            HealthItem(name: "proxy_auto_discovery", value: String(report.proxy.autoDiscovery)),
            HealthItem(name: "quic_udp_443", value: Self.format(report.quic)),
        ]

        for endpoint in report.endpoints {
            let host = endpoint.url.host() ?? endpoint.url.absoluteString
            var notes = [
                "TLS ≤1.2: \(Self.format(endpoint.tls12Only))",
                "route: \(endpoint.route)",
                "chain: \(endpoint.certificateChain.isEmpty ? "none" : endpoint.certificateChain.joined(separator: " ← "))",
            ]
            if let trustError = endpoint.trustError {
                notes.append("trust: \(trustError)")
            }
            if let timing = endpoint.timing {
                notes.append("timing: \(Self.format(timing))")
            }
            notes.append("request id: \(endpoint.traceId) — give this to the backend team to find in server logs/traces")
            if let cause = Self.likelyCause(for: endpoint) {
                notes.append("likely cause: \(cause)")
            }
            items.append(HealthItem(name: host, value: Self.format(endpoint.defaultTLS), footnote: notes.joined(separator: "\n")))
        }
        return items
    }

    private nonisolated static func format(_ outcome: ProbeOutcome) -> String {
        switch outcome {
        case .success(let milliseconds, let detail): return String(format: "%.0f ms · ", milliseconds) + detail
        case .failure(let reason): return reason
        }
    }

    private nonisolated static func format(_ timing: RequestTimingBreakdown) -> String {
        func part(_ label: String, _ ms: Double?) -> String {
            ms.map { String(format: "%@ %.0fms", label, $0) } ?? "\(label) —"
        }
        var parts = [part("DNS", timing.dnsLookupMs), part("Connect", timing.tcpConnectMs)]
        if timing.tlsHandshakeMs != nil || timing.stalledAt == "TLS handshake" {
            parts.append(part("TLS", timing.tlsHandshakeMs))
        }
        parts.append(part("TTFB", timing.timeToFirstByteMs))
        parts.append(part("Download", timing.contentDownloadMs))

        var line = parts.joined(separator: " · ")
        if let stalledAt = timing.stalledAt {
            line += " — stalled at \(stalledAt)"
        }
        if timing.usedProxy {
            line += " · via proxy"
        }
        return line
    }

    // Plain-English read of where a failed/timed-out request got stuck. Only the phase is known —
    // the actual server-side cause (a slow query, an unavailable downstream service, …) needs
    // server logs or tracing, found via the request id above.
    private nonisolated static func likelyCause(for endpoint: EndpointReport) -> String? {
        guard case .failure = endpoint.defaultTLS, let stalledAt = endpoint.timing?.stalledAt else { return nil }

        switch stalledAt {
        case "DNS lookup":
            return "Stalled resolving the hostname. This network's DNS is likely blocking or redirecting it."
        case "TCP connect":
            return "Stalled opening the connection. A firewall/proxy on this network is likely blocking the port, " +
                   "or the server is unreachable from here."
        case "TLS handshake":
            return "Stalled during the TLS handshake. A firewall or proxy on this network is likely interfering " +
                   "with TLS — compare with the TLS ≤1.2 result above."
        case "waiting for server response":
            return "Connected and sent the request, but got no response in time. This points at the server side " +
                   "— a slow/stuck backend, a database query, or an unavailable downstream service — not this " +
                   "device's network. Share the request id below with the backend/ops team to look up in their logs."
        case "downloading response":
            return "The server started responding but the transfer stalled, which usually means an unstable link " +
                   "or the server itself timing out mid-response."
        default:
            return nil
        }
    }

    private nonisolated static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond))
    }
}
