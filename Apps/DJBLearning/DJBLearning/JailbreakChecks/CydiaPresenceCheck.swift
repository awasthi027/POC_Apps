//
//  CydiaPresenceCheck.swift
//  DJBLearning
//

import UIKit

/// Check 6: Cydia / package manager URL scheme detection.
struct CydiaPresenceCheck: JailbreakCheck {
    func execute() -> JailbreakIndicator {
        let cydiaURL = URL(string: "cydia://")!
        let canOpenCydia = UIApplication.shared.canOpenURL(cydiaURL)
        
        return JailbreakIndicator(
            name: "Cydia Package Manager Detection",
            severity: .low,
            isTriggered: canOpenCydia,
            timestamp: Date()
        )
    }
}
