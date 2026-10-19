//
//  LaunchTimeTracker.swift
//  DebugLearning
//
//  Instruments app launch so you can see WHICH phase is slow:
//  process start -> App struct init -> ModelContainer setup -> first frame.
//
//  How to inspect:
//  1) Console.app / `log stream` — filter subsystem "DebugLearning", category
//     "LaunchTime" to see phase durations printed on every launch (device or sim).
//  2) Instruments -> "App Launch" template (Product ▸ Profile) — the OSSignposter
//     intervals below ("ModelContainerSetup", "FirstFrame", ...) show up as
//     labeled ranges on the "Points of Interest" / "os_signpost" track, right
//     next to Apple's own pre-main/main/first-frame markers.
//  3) Pre-main (dylib load/rebase/bind/ObjC setup) time isn't visible to app
//     code at all — enable it via Scheme ▸ Run ▸ Arguments ▸ Environment
//     Variables: DYLD_PRINT_STATISTICS = 1 (add DYLD_PRINT_STATISTICS_DETAILS
//     for a full breakdown). It prints to the Xcode console before your code runs.
//

import Foundation
import os

enum LaunchTimeTracker {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "DebugLearning"
    private static let log = Logger(subsystem: subsystem, category: "LaunchTime")
    private static let signposter = OSSignposter(subsystem: subsystem, category: "LaunchTime")

    /// systemUptime at process start approximated by capturing it as early as possible.
    private static let processStartUptime = ProcessInfo.processInfo.systemUptime
    private static var appInitTime: CFAbsoluteTime?
    private static var firstFrameRecorded = false

    /// Human-readable log of phase -> duration, surfaced in LaunchTimeView.
    private(set) static var recordedPhases: [(name: String, seconds: Double)] = []

    /// Call as the very first line of the App struct's init().
    static func markAppInit() {
        appInitTime = CFAbsoluteTimeGetCurrent()
        let sinceProcessStart = ProcessInfo.processInfo.systemUptime - processStartUptime
        record("Process start → App.init", sinceProcessStart)
    }

    /// Wrap any synchronous setup work (e.g. ModelContainer creation) to time it
    /// and emit a signpost interval visible in Instruments.
    static func measure<T>(_ name: StaticString, _ work: () throws -> T) rethrows -> T {
        let state = signposter.beginInterval(name)
        let start = CFAbsoluteTimeGetCurrent()
        defer {
            signposter.endInterval(name, state)
            record("\(name)", CFAbsoluteTimeGetCurrent() - start)
        }
        return try work()
    }

    /// Call from `.onAppear` on the very first screen. Guarded so only the
    /// first call (the actual first frame) is recorded.
    static func markFirstFrame() {
        guard !firstFrameRecorded, let appInitTime else { return }
        firstFrameRecorded = true
        record("App.init → first frame", CFAbsoluteTimeGetCurrent() - appInitTime)
    }

    private static func record(_ name: String, _ seconds: Double) {
        recordedPhases.append((name, seconds))
        log.debug("launch phase \(name, privacy: .public) took \(seconds, format: .fixed(precision: 4))s")
    }
}
