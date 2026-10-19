//
//  DevicePerformanceMonitor.swift
//  DeviceHealthLearning
//
//  Not part of TelemetrySDK. Surfaces the public signals iOS exposes about how loaded the device is
//  right now — thermal throttling, system-wide memory pressure, this app's own memory/CPU use, free
//  storage, and how old/capable the hardware is — which is as close as an app can get to answering
//  "is this device struggling, and could that be something else running on it?" without any
//  private API.
//
//  What this cannot see: which other app is using the CPU/RAM, what is in the background app
//  switcher, or anything else about other processes — Apple's sandbox does not expose that to any
//  app. System-wide memory pressure (DispatchSourceMemoryPressure) is the closest public signal to
//  "something on this device — possibly another app — is consuming a lot of memory."
//

import Foundation
import UIKit
import Observation

enum SystemMemoryPressure: String {
    case normal
    case warning
    case critical
}

// One performance event, equivalent to what the SDK posts to its data handler elsewhere in this app.
struct PerformanceEvent: Identifiable {
    enum Kind: String {
        case thermal_state_changed
        case memory_pressure_changed
        case memory_warning
    }

    let id = UUID()
    let kind: Kind
    let detail: String
    let date = Date()
}

@Observable
final class DevicePerformanceMonitor {
    // Static facts about this device/hardware; these never change while the app is running.
    let deviceIdentifier = DeviceModel.identifier
    let deviceFriendlyName = DeviceModel.friendlyName
    let deviceReleaseYear = DeviceModel.releaseYear
    let deviceAgeInYears = DeviceModel.ageInYears
    let systemVersion = UIDevice.current.systemVersion
    let totalMemoryGB = Double(ProcessInfo.processInfo.physicalMemory) / 1024 / 1024 / 1024
    let activeProcessorCount = ProcessInfo.processInfo.activeProcessorCount
    let processorCount = ProcessInfo.processInfo.processorCount

    private(set) var thermalState = ProcessInfo.processInfo.thermalState
    private(set) var memoryPressure: SystemMemoryPressure = .normal
    private(set) var appMemoryFootprintMB: Double?
    private(set) var availableMemoryBeforeTerminationMB: Double?
    private(set) var appCPUUsagePercent: Double?
    private(set) var freeDiskSpaceGB: Double?
    private(set) var totalDiskSpaceGB: Double?
    private(set) var memoryWarningCount = 0
    private(set) var events: [PerformanceEvent] = []

    var lowPowerMode: Bool { ProcessInfo.processInfo.isLowPowerModeEnabled }
    var systemUptime: TimeInterval { ProcessInfo.processInfo.systemUptime }
    var backgroundRefreshStatus: UIBackgroundRefreshStatus { UIApplication.shared.backgroundRefreshStatus }

    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private var observers: [NSObjectProtocol] = []
    private var isObserving = false

    func startObserving() {
        guard !isObserving else { return }
        isObserving = true

        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.thermalStateChanged() }
            },
            center.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.memoryWarningReceived() }
            },
        ]

        // Only fires on a change, so the state stays `.normal` (a reasonable default) until the
        // first warning or critical event arrives.
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler { [weak self, weak source] in
            guard let self, let event = source?.data else { return }
            MainActor.assumeIsolated { self.memoryPressureChanged(event) }
        }
        source.resume()
        memoryPressureSource = source

        refresh()
    }

    func stopObserving() {
        guard isObserving else { return }
        isObserving = false

        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        memoryPressureSource?.cancel()
        memoryPressureSource = nil
    }

    // Re-reads the point-in-time measurements: memory footprint, CPU usage, and disk space.
    func refresh() {
        appMemoryFootprintMB = ProcessMetrics.memoryFootprintMB()
        appCPUUsagePercent = ProcessMetrics.cpuUsagePercent()
        availableMemoryBeforeTerminationMB = ProcessMetrics.availableMemoryBeforeTerminationMB()
        if let disk = ProcessMetrics.diskSpaceGB() {
            freeDiskSpaceGB = disk.free
            totalDiskSpaceGB = disk.total
        }
    }

    private func thermalStateChanged() {
        thermalState = ProcessInfo.processInfo.thermalState
        post(.thermal_state_changed, detail: thermalState.description)
    }

    private func memoryWarningReceived() {
        memoryWarningCount += 1
        post(.memory_warning, detail: "warning #\(memoryWarningCount) this session")
        refresh()
    }

    private func memoryPressureChanged(_ event: DispatchSource.MemoryPressureEvent) {
        let level: SystemMemoryPressure = event.contains(.critical) ? .critical : (event.contains(.warning) ? .warning : .normal)
        guard level != memoryPressure else { return }
        memoryPressure = level
        post(.memory_pressure_changed, detail: level.rawValue)
        refresh()
    }

    private func post(_ kind: PerformanceEvent.Kind, detail: String) {
        events.insert(PerformanceEvent(kind: kind, detail: detail), at: 0)
    }
}

extension ProcessInfo.ThermalState {
    var description: String {
        switch self {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }
}
