//
//  ApplicationRestrictionsCheck.swift
//  DJBLearning
//

import Foundation

/// Check 5: Application restrictions bypass detection.
/// Uses REAL write attempts (see `JailbreakCheckUtils.canActuallyWrite`)
/// instead of `isWritableFile()`/`access()`, which can misreport
/// permissions under the iOS sandbox and false-positive on stock devices.
struct ApplicationRestrictionsCheck: JailbreakCheck {
    func execute() -> JailbreakIndicator {
        let fileManager = FileManager.default
        var restrictionsBypassCount = 0
        
        if JailbreakCheckUtils.canActuallyWrite(toPath: "/private/etc/hosts") {
            restrictionsBypassCount += 1
        }
        
        // Rootless jailbreak (iOS 15+) marker directory
        if fileManager.fileExists(atPath: "/var/jb") {
            restrictionsBypassCount += 1
        }
        
        // Classic (rootful) jailbreak marker - root filesystem remounted read-write
        if JailbreakCheckUtils.canActuallyWrite(toPath: "/Applications/.jb_test_\(UUID().uuidString)", createIfMissing: true) {
            restrictionsBypassCount += 1
        }
        
        let isTriggered = restrictionsBypassCount >= 1
        return JailbreakIndicator(
            name: "Application Restrictions Bypass",
            severity: isTriggered ? .medium : .low,
            isTriggered: isTriggered,
            timestamp: Date()
        )
    }
}
