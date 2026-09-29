//
//  JailbreakCheckUtils.swift
//  DJBLearning
//
//  Shared low-level helpers used by multiple JailbreakCheck implementations.
//

import Foundation
import Darwin

/// Shared low-level helpers used by multiple `JailbreakCheck` implementations.
/// Kept separate from the engine so checks can be unit tested / reused
/// independently.
enum JailbreakCheckUtils {
    
    /// Attempts a REAL write operation to determine sandbox permission, since
    /// `FileManager.isWritableFile(atPath:)` / POSIX `access()` only inspect
    /// permission bits and can report false positives under the iOS sandbox
    /// (enforcement happens at open()/write() time, not access() time).
    /// - Parameters:
    ///   - path: Absolute path to attempt to write to.
    ///   - createIfMissing: If true, attempts to create a brand-new file at
    ///     `path` (used for directories like /Applications where the target
    ///     file doesn't exist yet). If false, attempts to open an existing
    ///     file for writing without truncating or modifying its contents.
    static func canActuallyWrite(toPath path: String, createIfMissing: Bool = false) -> Bool {
        let fileManager = FileManager.default
        
        if createIfMissing {
            let created = fileManager.createFile(atPath: path, contents: nil, attributes: nil)
            if created {
                try? fileManager.removeItem(atPath: path)
            }
            return created
        }
        
        // Open existing file for writing (O_WRONLY, no O_TRUNC/O_CREAT) so we
        // never modify its contents - we only care whether open() succeeds.
        let fd = open(path, O_WRONLY)
        if fd >= 0 {
            close(fd)
            return true
        }
        return false
    }
    
    /// Detects if a debugger is currently attached via sysctl. Used to avoid
    /// false positives from Xcode-injected DYLD_* variables.
    static func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        guard result == 0 else { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }
}
