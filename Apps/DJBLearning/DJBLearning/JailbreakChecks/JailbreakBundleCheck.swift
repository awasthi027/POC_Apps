//
//  JailbreakBundleCheck.swift
//  DJBLearning
//

import Foundation

/// Check 8: Jailbreak bundle detection.
/// Scans /Applications for known jailbreak app bundle identifiers.
struct JailbreakBundleCheck: JailbreakCheck {
    func execute() -> JailbreakIndicator {
        let jailbreakBundles: Set<String> = [
            "com.saurik.Cydia",
            "jp.ashikase.SBSettings",
            "jp.ashikase.DoesNotDisturb",
            "kr.xo.spark",
            "me.ihacklog.uthentication",
            "com.fortysixandtwo.ClassicBands",
            "com.fortysixandtwo.karoo",
            "kr.devdon.ifilemanager",
            "com.conradkramer.Icy",
            "org.coolstar.modmyi"
        ]
        
        let fileManager = FileManager.default
        var foundBundles = 0
        
        let applicationsPath = "/Applications"
        if let appDirs = try? fileManager.contentsOfDirectory(atPath: applicationsPath) {
            for appDir in appDirs {
                let infoPlistPath = applicationsPath.appending("/\(appDir)/Info.plist")
                if let bundleId = NSDictionary(contentsOfFile: infoPlistPath)?["CFBundleIdentifier"] as? String,
                   jailbreakBundles.contains(bundleId) {
                    foundBundles += 1
                }
            }
        }
        
        let isTriggered = foundBundles > 0
        return JailbreakIndicator(
            name: "Jailbreak Bundle Detection",
            severity: isTriggered ? .high : .low,
            isTriggered: isTriggered,
            timestamp: Date()
        )
    }
}
