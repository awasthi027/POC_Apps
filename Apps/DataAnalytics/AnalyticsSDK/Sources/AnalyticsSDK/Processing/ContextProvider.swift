import Foundation

/// Source of environment metadata. Kept apart from `EventProcessor` so what is collected is auditable in one
/// place and replaceable in tests.
protocol ContextProvider: Sendable {
    func currentContext() -> EventContext
}

struct DefaultContextProvider: ContextProvider {
    private let connectivity: any ConnectivityMonitor
    private let appVersion: String
    private let appBuild: String
    private let deviceModel: String
    private let osName: String
    private let osVersion: String

    init(connectivity: any ConnectivityMonitor, bundle: Bundle = .main) {
        self.connectivity = connectivity
        let info = bundle.infoDictionary ?? [:]
        appVersion = info["CFBundleShortVersionString"] as? String ?? "unknown"
        appBuild = info["CFBundleVersion"] as? String ?? "unknown"
        deviceModel = Self.hardwareModel()
        let v = ProcessInfo.processInfo.operatingSystemVersion
        osVersion = "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        #if os(iOS)
        osName = "iOS"
        #else
        osName = "macOS"
        #endif
    }

    func currentContext() -> EventContext {
        let status = connectivity.currentStatus
        return EventContext(appVersion: appVersion, appBuild: appBuild, osName: osName, osVersion: osVersion,
                            deviceModel: deviceModel,
                            // Locale/time zone change at runtime (Settings), so they are read per event.
                            locale: Locale.current.identifier, timeZone: TimeZone.current.identifier,
                            networkType: status.isConnected ? status.interface.rawValue : "none",
                            sdkVersion: AnalyticsSDKInfo.version)
    }

    /// Marketing-agnostic hardware identifier such as "iPhone15,2". Not unique per device.
    private static func hardwareModel() -> String {
        if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return sim }
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        guard size > 0 else { return "unknown" }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }
}
