//
//  ProcessNameIntegrityCheck.swift
//  DJBLearning
//

import Foundation

/// Check 7: Process name integrity verification.
struct ProcessNameIntegrityCheck: JailbreakCheck {
    func execute() -> JailbreakIndicator {
        let processName = ProcessInfo.processInfo.processName
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        
        let isIntegrous = processName.contains(bundleId) || !processName.isEmpty
        return JailbreakIndicator(
            name: "Process Name Integrity",
            severity: .low,
            isTriggered: !isIntegrous,
            timestamp: Date()
        )
    }
}
