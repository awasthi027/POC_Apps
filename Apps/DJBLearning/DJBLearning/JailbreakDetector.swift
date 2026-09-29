//
//  JailbreakDetector.swift
//  DJBLearning
//
//  Robust Jailbreak Detection Logic
//  Minimizes false positives across iOS versions
//
//  ARCHITECTURE (Dependency Injection):
//  -------------------------------------
//  JailbreakDetector is a pure *engine* - it knows nothing about how any
//  individual check works. Each check is a small type conforming to the
//  `JailbreakCheck` protocol (see JailbreakCheck.swift), and checks are
//  INJECTED into the shared detector from outside (e.g. app startup code)
//  via `register(_:)`.
//
//  Concrete check implementations live in their own files under
//  JailbreakChecks/ (e.g. SandboxIntegrityCheck.swift), and the convenience
//  factory that bundles the default set lives in
//  JailbreakChecks/StandardJailbreakChecks.swift.
//
//  This means:
//  - The detector's scoring/threshold logic is fully decoupled from the
//    actual detection heuristics.
//  - New checks can be added, removed, or swapped (e.g. per iOS version, per
//    build configuration, for testing/mocking) without touching the engine.
//  - Consumers control exactly which checks run by injecting only the ones
//    they want.
//
//  Usage:
//  ```swift
//  JailbreakDetector.shared.register(StandardJailbreakChecks.all)
//  let result = JailbreakDetector.shared.detectJailbreak()
//  ```
//

import Foundation
import UIKit

/// Pure scoring/orchestration engine. Contains NO detection logic itself -
/// all heuristics are injected via `register(_:)` as `JailbreakCheck`
/// conforming types.
final class JailbreakDetector {
    
    // MARK: - Singleton
    static let shared = JailbreakDetector()
    
    /// Checks currently registered with the detector. Populated exclusively
    /// via `register(_:)` - the engine never creates checks itself.
    private(set) var checks: [JailbreakCheck] = []
    
    /// Minimum accumulated severity score (0-100) required to consider the
    /// device jailbroken. Can be tuned per iOS version/build if needed.
    var minRiskThreshold: Int = 60
    
    private init() {}
    
    // MARK: - Registration API (Injection Points)
    
    /// Injects a single check into the engine.
    func register(_ check: JailbreakCheck) {
        checks.append(check)
    }
    
    /// Injects multiple checks into the engine at once.
    func register(_ checks: [JailbreakCheck]) {
        self.checks.append(contentsOf: checks)
    }
    
    /// Removes all currently registered checks. Useful for tests or when
    /// re-configuring checks per iOS version/build.
    func removeAllChecks() {
        checks.removeAll()
    }
    
    // MARK: - Public API
    
    /// Main detection method - executes all registered checks and returns a
    /// comprehensive jailbreak detection result. Combines multiple detection
    /// techniques to minimize false positives.
    func detectJailbreak() -> JailbreakDetectionResult {
        let iosVersion = UIDevice.current.systemVersion
        
        var indicators: [JailbreakIndicator] = []
        var totalScore = 0
        
        for check in checks {
            let indicator = check.execute()
            indicators.append(indicator)
            
            if indicator.isTriggered {
                totalScore += indicator.severity.score
            }
        }
        
        let riskScore = min(totalScore, 100)
        let isJailbroken = riskScore >= minRiskThreshold
        
        let result = JailbreakDetectionResult(
            isJailbroken: isJailbroken,
            detectionMethod: "Multi-indicator behavioral analysis (v3.0 - injectable checks)",
            riskScore: riskScore,
            indicators: indicators,
            iosVersion: iosVersion
        )
        
        logDetectionResult(result)
        
        return result
    }
    
    /// Logs detection results (should be redacted in production)
    private func logDetectionResult(_ result: JailbreakDetectionResult) {
        #if DEBUG
        print("🔍 Jailbreak Detection Report")
        print("iOS Version: \(result.iosVersion)")
        print("Risk Score: \(result.riskScore)/100")
        print("Status: \(result.isJailbroken ? "⚠️ JAILBROKEN" : "✅ SAFE")")
        print("Indicators:")
        for indicator in result.indicators {
            let status = indicator.isTriggered ? "🔴" : "🟢"
            print("  \(status) \(indicator.name) - \(indicator.severity)")
        }
        #endif
    }
}
