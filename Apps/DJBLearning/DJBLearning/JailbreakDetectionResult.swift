//
//  JailbreakDetectionResult.swift
//  DJBLearning
//
//  Result/value types returned by the jailbreak detection engine.
//

import Foundation

/// Represents the detection result with details about the verdict
struct JailbreakDetectionResult {
    let isJailbroken: Bool
    let detectionMethod: String
    let riskScore: Int // 0-100, threshold is 60 for positive detection
    let indicators: [JailbreakIndicator]
    let iosVersion: String
}

/// Individual indicator of potential jailbreak
struct JailbreakIndicator {
    let name: String
    let severity: Severity // Low, Medium, High
    let isTriggered: Bool
    let timestamp: Date
    
    enum Severity {
        case low
        case medium
        case high
    }
}

extension JailbreakIndicator.Severity {
    var score: Int {
        switch self {
        case .low: return 10
        case .medium: return 30
        case .high: return 50
        }
    }
    
    var description: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}
