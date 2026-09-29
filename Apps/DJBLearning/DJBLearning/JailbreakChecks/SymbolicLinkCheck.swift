//
//  SymbolicLinkCheck.swift
//  DJBLearning
//

import Foundation

/// Check 3: Symbolic link detection.
/// Tests ability to create symbolic links within the app's own sandbox.
struct SymbolicLinkCheck: JailbreakCheck {
    func execute() -> JailbreakIndicator {
        let fileManager = FileManager.default
        let tempDir = NSTemporaryDirectory()
        let testFile = tempDir.appending("test_file_\(UUID().uuidString)")
        let testLink = tempDir.appending("test_link_\(UUID().uuidString)")
        
        defer {
            try? fileManager.removeItem(atPath: testLink)
            try? fileManager.removeItem(atPath: testFile)
        }
        
        fileManager.createFile(atPath: testFile, contents: nil, attributes: nil)
        _ = try? fileManager.createSymbolicLink(atPath: testLink, withDestinationPath: testFile)
        
        // This check is informational only in the sandbox (creating a symlink
        // inside the app's own container is always allowed) - kept as a
        // low-severity signal for completeness.
        return JailbreakIndicator(
            name: "Symbolic Link Capability",
            severity: .low,
            isTriggered: false,
            timestamp: Date()
        )
    }
}
