//
//  DylibInjectionCheck.swift
//  DJBLearning
//

import Foundation

/// Check 2: Dylib injection detection.
/// Detects if known jailbreak framework dylibs are present on disk.
struct DylibInjectionCheck: JailbreakCheck {
    func execute() -> JailbreakIndicator {
        let jailbreakLibPaths = [
            "/usr/lib/libsubstrate.dylib",
            "/Library/Frameworks/CydiaSubstrate.framework",
            "/Library/MobileSubstrate/DynamicLibraries"
        ]
        
        let fileManager = FileManager.default
        let foundCount = jailbreakLibPaths.filter { fileManager.fileExists(atPath: $0) }.count
        
        let isTriggered = foundCount > 0
        return JailbreakIndicator(
            name: "Dylib Injection Detection",
            severity: isTriggered ? .high : .low,
            isTriggered: isTriggered,
            timestamp: Date()
        )
    }
}
