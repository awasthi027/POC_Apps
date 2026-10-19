//
//  BatteryHealthMonitor.swift
//  DeviceHealthLearning
//
//  Ported from TelemetrySDK BatteryInformationProvider (+Common, +iOS, +ChargeRate, +CriticalLevel).
//

import UIKit
import Observation

// Mirrors TelemetrySDK `BatteryChargingState`.
enum BatteryChargingState: String {
    case unknown
    case discharging
    case charging
    case full
}

// Mirrors TelemetrySDK `BatteryPluggedState`. Plug types other than USB cannot be determined on iOS.
enum BatteryPluggedState: String {
    case unknown
    case pluggedUSB
    case unplugged
}

extension UIDevice.BatteryState {
    var chargingState: BatteryChargingState {
        switch self {
        case .charging: return .charging
        case .full: return .full
        case .unplugged: return .discharging
        default: return .unknown
        }
    }

    var pluggedState: BatteryPluggedState {
        switch self {
        case .charging, .full: return .pluggedUSB
        case .unplugged: return .unplugged
        default: return .unknown
        }
    }
}

// One battery level reading, persisted to compute the charge rate.
struct BatteryLevelSample: Codable {
    let batteryLevel: Float
    let epochTimeStamp: TimeInterval
}

// A battery event, equivalent to what the SDK posts to its data handler.
struct BatteryEvent: Identifiable {
    enum Kind: String {
        case critical_battery_level
        case power_saver_mode_changed
    }

    let id = UUID()
    let kind: Kind
    let detail: String
    let date = Date()
}

@Observable
final class BatteryHealthMonitor {
    static let batteryType = "Li-ion"
    private static let chargeRateListSaveKey = "CHARGE_RATE_LIST_SAVE_KEY"
    private static let sampleWindow: TimeInterval = 60 * 60

    private let device = UIDevice.current
    private let userDefaults: UserDefaults

    private(set) var batteryLevel: Float?
    private(set) var chargingStatus: BatteryChargingState = .unknown
    private(set) var pluggedType: BatteryPluggedState = .unknown
    private(set) var chargeRate: Float?
    private(set) var lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    private(set) var pluggedInTimeStamp: TimeInterval?
    private(set) var unPluggedTimeStamp: TimeInterval?
    private(set) var events: [BatteryEvent] = []
    private(set) var sampleCount = 0

    private var samples: [BatteryLevelSample] = []
    private var initialDevicePluggedState: UIDevice.BatteryState = .unknown
    private var previousCriticalLevel: Float = 1.0
    private var observers: [NSObjectProtocol] = []
    private var isObserving = false

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        restorePersistedSamples()
    }

    // MARK: - Lifecycle (SDK: startObserving / stopObserving)

    func startObserving() {
        guard !isObserving else { return }
        isObserving = true

        device.isBatteryMonitoringEnabled = true
        initialDevicePluggedState = device.batteryState

        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: UIDevice.batteryStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.powerSourceChanged() }
            },
            center.addObserver(forName: UIDevice.batteryLevelDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.batteryLevelChanged() }
            },
            center.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.lowPowerModeChanged() }
            },
        ]

        refresh()
    }

    func stopObserving() {
        guard isObserving else { return }
        isObserving = false

        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        device.isBatteryMonitoringEnabled = false
        initialDevicePluggedState = .unknown
        resetTimeStamps()
    }

    // Re-reads all pullable attributes. Reading the charge rate also records a sample, like the SDK.
    func refresh() {
        batteryLevel = readBatteryLevel()
        chargingStatus = device.batteryState.chargingState
        pluggedType = device.batteryState.pluggedState
        lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        chargeRate = readChargeRate()
    }

    // MARK: - Attributes

    // Battery level in percent (0-100), or nil when unavailable (e.g. Simulator reports -1).
    private func readBatteryLevel() -> Float? {
        let level = device.batteryLevel
        guard level > 0 else { return nil }
        return level * 100
    }

    // SDK `batteryChargeRate`: save the current level, then return the least-squares slope in %/hour.
    private func readChargeRate() -> Float? {
        if let level = readBatteryLevel() {
            saveSample(batteryLevel: level)
        }
        return computeChargeRate()
    }

    // Time on charger, in seconds.
    var timeSpentOnCharger: TimeInterval? {
        pluggedInTimeStamp.map { Date().timeIntervalSince1970 - $0 }
    }

    // Time since unplugged, in seconds.
    var timeSinceUnpluggedFromCharger: TimeInterval? {
        unPluggedTimeStamp.map { Date().timeIntervalSince1970 - $0 }
    }

    // MARK: - Plug state tracking (SDK: powerSourceChanged)

    private var isDeviceUnplugged: Bool { device.batteryState.pluggedState == .unplugged }
    // Not the negation of isDeviceUnplugged: the state may be `.unknown`.
    private var isDeviceOnPower: Bool { device.batteryState.pluggedState == .pluggedUSB }

    private func powerSourceChanged() {
        let deviceOnPower = isDeviceOnPower
        let deviceUnPlugged = isDeviceUnplugged

        if deviceOnPower && pluggedInTimeStamp == nil && initialDevicePluggedState != .charging {
            pluggedInTimeStamp = Date().timeIntervalSince1970
            unPluggedTimeStamp = nil
        } else if deviceUnPlugged {
            unPluggedTimeStamp = Date().timeIntervalSince1970
            pluggedInTimeStamp = nil
        } else if !deviceOnPower && !deviceUnPlugged {
            resetTimeStamps()
        }

        // Only needed for the first callback after start.
        initialDevicePluggedState = .unknown
        refresh()
    }

    private func resetTimeStamps() {
        unPluggedTimeStamp = nil
        pluggedInTimeStamp = nil
    }

    // MARK: - Low power mode (SDK: lowPowerModeChanged)

    private func lowPowerModeChanged() {
        lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        post(.power_saver_mode_changed, detail: "lowPowerMode = \(lowPowerMode)")
    }

    // MARK: - Critical level (SDK: startCriticalBatteryPublisher / shouldEmitEventFor)

    private func batteryLevelChanged() {
        // Round to 2 digits, e.g. 0.1051 -> 0.11, so the ranges are easy to reason about.
        let rounded = (device.batteryLevel * 100).rounded(.toNearestOrAwayFromZero) / 100
        if shouldEmitEventFor(currentLevel: rounded, previousLevel: previousCriticalLevel) {
            post(.critical_battery_level, detail: "level = \(Int(rounded * 100))%")
        }
        previousCriticalLevel = rounded
        refresh()
    }

    func shouldEmitEventFor(currentLevel: Float, previousLevel: Float) -> Bool {
        // No event while on power.
        guard !isDeviceOnPower else { return false }

        switch currentLevel {
        case 0.16...0.20 where previousLevel > 0.20: return true
        case 0.11...0.15 where previousLevel > 0.15: return true
        case 0.00...0.10 where previousLevel > currentLevel: return true
        default: return false // above 20% or -1 (unknown)
        }
    }

    private func post(_ kind: BatteryEvent.Kind, detail: String) {
        events.insert(BatteryEvent(kind: kind, detail: detail), at: 0)
    }

    // MARK: - Charge rate (SDK: +ChargeRate)

    private func restorePersistedSamples() {
        guard let data = userDefaults.data(forKey: Self.chargeRateListSaveKey) else { return }
        samples = (try? JSONDecoder().decode([BatteryLevelSample].self, from: data)) ?? []
        filterStaleSamples()
    }

    private func saveSample(batteryLevel: Float, epoch: TimeInterval = Date().timeIntervalSince1970) {
        samples.append(BatteryLevelSample(batteryLevel: batteryLevel, epochTimeStamp: epoch))
        filterStaleSamples()
        if let data = try? JSONEncoder().encode(samples) {
            userDefaults.set(data, forKey: Self.chargeRateListSaveKey)
        }
    }

    // Keep only samples from the last hour.
    private func filterStaleSamples() {
        let now = Date().timeIntervalSince1970
        samples.removeAll { $0.epochTimeStamp + Self.sampleWindow < now }
        sampleCount = samples.count
    }

    // Least squares regression slope of level (%) over time (s), scaled to %/hour.
    // https://www.mathsisfun.com/data/least-squares-regression.html
    private func computeChargeRate() -> Float? {
        guard samples.count >= 2, let head = samples.first else { return nil }

        let n = Double(samples.count)
        let x = samples.map { $0.epochTimeStamp - head.epochTimeStamp }
        let y = samples.map { Double($0.batteryLevel) }
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).reduce(0) { $0 + $1.0 * $1.1 }
        let sumXSquared = x.reduce(0) { $0 + $1 * $1 }

        let denominator = n * sumXSquared - sumX * sumX
        // All samples at the same timestamp: slope is undefined.
        guard denominator != 0 else { return nil }

        let slope = (n * sumXY - sumX * sumY) / denominator
        return Float(slope * 60 * 60)
    }
}
