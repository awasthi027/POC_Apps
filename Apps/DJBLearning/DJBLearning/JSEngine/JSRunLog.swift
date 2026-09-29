//
//  JSRunLog.swift
//  DJBLearning
//
//  Collects `native_Log` / `native_ReportException` calls made by the JS
//  rule set while it executes, so the UI can show what the script did.
//

import Foundation

struct JSLogLine: Identifiable {
    let id = UUID()
    let level: String
    let message: String
}

/// Sink passed into the JS bridge so `native_Log`/`native_ReportException`
/// calls made from `decoded_payload.js` are captured instead of only going
/// to the console.
final class JSRunLog {
    private(set) var lines: [JSLogLine] = []
    private(set) var exceptions: [String] = []

    func log(level: String, message: String) {
        lines.append(JSLogLine(level: level, message: message))
        #if DEBUG
        print("🟨 JS[\(level)]: \(message)")
        #endif
    }

    func reportException(_ message: String) {
        exceptions.append(message)
        #if DEBUG
        print("🟥 JS exception: \(message)")
        #endif
    }
}
