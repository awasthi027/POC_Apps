//
//  SandboxIntegrityCheck.swift
//  DJBLearning
//

import Foundation

/// Check 1: Sandbox integrity test.
/// Tests ability to write to restricted directories using a REAL write
/// attempt (see `JailbreakCheckUtils.canActuallyWrite`) rather than
/// `isWritableFile()`/`access()`, which can misreport permissions under the
/// iOS sandbox.
struct SandboxIntegrityCheck: JailbreakCheck {
    func execute() -> JailbreakIndicator {
        let restrictedDirs = [
            "/Applications",
            "/Library/Ringtones",
            "/Library/Wallpaper",
            "/usr/bin"
        ]
        
        var vulnerablePathCount = 0
        let fileManager = FileManager.default
        
        for dir in restrictedDirs {
            guard fileManager.fileExists(atPath: dir) else { continue }
            let testPath = dir.appending("/.jb_test_\(UUID().uuidString)")
            if JailbreakCheckUtils.canActuallyWrite(toPath: testPath, createIfMissing: true) {
                vulnerablePathCount += 1
            }
        }
        
        let isTriggered = vulnerablePathCount >= 2
        return JailbreakIndicator(
            name: "Sandbox Integrity Breach",
            severity: isTriggered ? .high : .low,
            isTriggered: isTriggered,
            timestamp: Date()
        )
    }
}
