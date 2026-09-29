//
//  JailbreakEnvironmentCheck.swift
//  DJBLearning
//

import Foundation

/// Check 4: Jailbreak tool environment variable detection.
/// Inspects the *value* of DYLD_* env vars (not just presence), because
/// Xcode/Simulator/TestFlight debug builds legitimately set these for
/// Address Sanitizer, Thread Sanitizer, Main Thread Checker, and view
/// debugging. Flagging mere presence caused false positives on every
/// Xcode-run build.
struct JailbreakEnvironmentCheck: JailbreakCheck {
    func execute() -> JailbreakIndicator {
        #if DEBUG
        // Xcode's own tooling injects DYLD_* variables in Debug builds.
        return notTriggeredResult()
        #else
        if JailbreakCheckUtils.isDebuggerAttached() {
            return notTriggeredResult()
        }
        
        let jailbreakPathMarkers = [
            "MobileSubstrate",
            "libsubstrate",
            "CydiaSubstrate",
            "frida",
            "TweakInject",
            "/var/jb/",
            "/Library/MobileSubstrate"
        ]
        
        let appleDebugMarkers = [
            "libMainThreadChecker",
            "libViewDebuggerSupport",
            "libBacktraceRecording",
            "libMTLCapture",
            "/Developer/",
            "libclang_rt"
        ]
        
        let dyldVarsToInspect = [
            "DYLD_INSERT_LIBRARIES",
            "DYLD_LIBRARY_PATH",
            "DYLD_FRAMEWORK_PATH"
        ]
        
        var foundSuspiciousVars = 0
        for envVar in dyldVarsToInspect {
            guard let raw = getenv(envVar) else { continue }
            let value = String(cString: raw)
            
            if appleDebugMarkers.contains(where: { value.contains($0) }) { continue }
            if jailbreakPathMarkers.contains(where: { value.contains($0) }) {
                foundSuspiciousVars += 1
            }
        }
        
        let isTriggered = foundSuspiciousVars > 0
        return JailbreakIndicator(
            name: "Jailbreak Environment Detection",
            severity: isTriggered ? .high : .low,
            isTriggered: isTriggered,
            timestamp: Date()
        )
        #endif
    }
    
    private func notTriggeredResult() -> JailbreakIndicator {
        JailbreakIndicator(
            name: "Jailbreak Environment Detection",
            severity: .low,
            isTriggered: false,
            timestamp: Date()
        )
    }
}
