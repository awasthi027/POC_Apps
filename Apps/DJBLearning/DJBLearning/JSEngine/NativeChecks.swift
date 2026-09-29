//
//  NativeChecks.swift
//  DJBLearning
//
//  Real Darwin/Foundation implementations backing the `native_*` functions
//  that `decoded_payload.js` expects to call. Kept separate from
//  `JSNativeBridge` so the low-level syscall/Foundation logic can be read,
//  tested, and reused independently of JavaScriptCore.
//

import Foundation
import Darwin
import MachO
import CryptoKit

// `csops`, `ptrace` and `fork` are real Darwin syscalls. `csops`/`ptrace`
// aren't declared in the public iOS SDK headers Swift imports, and `fork()`
// IS declared but marked unavailable on Apple platforms by the Swift
// overlay (it steers you towards posix_spawn). The symbols are exported by
// libSystem regardless, so we bind them ourselves to bypass the Swift-level
// restriction for this deliberate sandbox-integrity probe.
@_silgen_name("csops")
private func c_csops(_ pid: pid_t, _ ops: UInt32, _ useraddr: UnsafeMutableRawPointer?, _ usersize: Int) -> Int32

@_silgen_name("ptrace")
@discardableResult
private func c_ptrace(_ request: Int32, _ pid: pid_t, _ addr: UnsafeMutableRawPointer?, _ data: Int32) -> Int32

@_silgen_name("fork")
private func c_fork() -> pid_t

enum NativeChecks {

    // MARK: - Mounts (backs native_GetFileSystemAttributes / native_GetFileSystemCount)

    /// Reads live mount table entries via `getmntinfo`, matching the shape
    /// `decoded_payload.js` expects: mntfromname, mntonname, fstypename, flags.
    static func fileSystemAttributes() -> [[String: Any]] {
        var mntbufp: UnsafeMutablePointer<statfs>?
        let count = getmntinfo(&mntbufp, MNT_NOWAIT)
        guard count > 0, let buf = mntbufp else { return [] }

        var results: [[String: Any]] = []
        results.reserveCapacity(Int(count))
        for i in 0..<Int(count) {
            let fs = buf[i]
            results.append([
                "mntfromname": cString(from: fs.f_mntfromname),
                "mntonname": cString(from: fs.f_mntonname),
                "fstypename": cString(from: fs.f_fstypename),
                "flags": Int(fs.f_flags)
            ])
        }
        return results
    }

    private static func cString<T>(from tuple: T) -> String {
        withUnsafeBytes(of: tuple) { raw -> String in
            let ptr = raw.baseAddress!.assumingMemoryBound(to: CChar.self)
            return String(cString: ptr)
        }
    }

    // MARK: - Debugger (backs native_CheckDebugPermission)

    static func isDebuggerAttached() -> Bool {
        JailbreakCheckUtils.isDebuggerAttached()
    }

    // MARK: - Environment variable hash matching (backs native_CheckEnvironmentVariablePresent)

    /// The payload passes a SHA-256 digest of a (secret, obfuscated) target
    /// environment variable *name* rather than the plaintext name itself.
    /// Since we don't know the original strings, we hash every environment
    /// variable name actually present in this process and compare digests -
    /// this reproduces the intended check without needing the plaintext.
    static func environmentVariableMatchesHash(_ targetHash: [UInt8]) -> Bool {
        guard targetHash.count == 32 else { return false }
        for key in ProcessInfo.processInfo.environment.keys {
            let digest = Array(SHA256.hash(data: Data(key.utf8)))
            if digest == targetHash { return true }
        }
        return false
    }

    // MARK: - MAC policy enforcement (backs native_CheckVnodeEnforce / native_CheckProcEnforce)

    static func isVnodeEnforced() -> Bool {
        sysctlBoolDefaultingTrue(name: "security.mac.vnode_enforce")
    }

    static func isProcEnforced() -> Bool {
        sysctlBoolDefaultingTrue(name: "security.mac.proc_enforce")
    }

    /// Reads an integer sysctl. If the sysctl isn't present/permitted under
    /// the App Sandbox (common on stock iOS), we can't prove it's disabled,
    /// so we default to `true` (enforced) rather than risk a false positive.
    private static func sysctlBoolDefaultingTrue(name: String) -> Bool {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname(name, &value, &size, nil, 0)
        guard result == 0 else { return true }
        return value != 0
    }

    // MARK: - Code signing enforcement (backs native_CheckCodeSigningPermissions)

    private static let csOpsStatus: UInt32 = 0 // CS_OPS_STATUS
    private static let csValid: UInt32 = 0x1
    private static let csEnforcement: UInt32 = 0x1000

    static func isCodeSigningEnforced() -> Bool {
        var flags: UInt32 = 0
        let result = withUnsafeMutablePointer(to: &flags) { ptr -> Int32 in
            c_csops(getpid(), csOpsStatus, ptr, MemoryLayout<UInt32>.size)
        }
        guard result == 0 else { return true } // Can't verify -> don't false-positive
        return (flags & csValid) != 0 && (flags & csEnforcement) != 0
    }

    // MARK: - Dylib inspection (backs native_CheckDynamicLibraryLoading / ...RuntimeCheck)

    static func isAnyDylibLoaded(matching needles: [String]) -> Bool {
        let count = _dyld_image_count()
        for i in 0..<count {
            guard let namePtr = _dyld_get_image_name(i) else { continue }
            let name = String(cString: namePtr)
            if needles.contains(where: { !$0.isEmpty && name.localizedCaseInsensitiveContains($0) }) {
                return true
            }
        }
        return false
    }

    // MARK: - Filesystem stat (backs native_GetFileStatistics)

    static func fileStatistics(atPath path: String) -> [String: Any] {
        var st = stat()
        let result = stat(path, &st)
        guard result == 0 else {
            return ["call_result": Int(-1)]
        }
        return [
            "call_result": Int(0),
            "st_size": Int(st.st_size),
            "st_mode": Int(st.st_mode),
            "st_nlink": Int(st.st_nlink)
        ]
    }

    // MARK: - Write probing (backs native_CreateFileSystemItemAtLocation)

    /// The JS payload only cares whether it *could* create the file (the
    /// `content` argument is a diagnostic marker string) - we reuse the same
    /// real-write-attempt technique as the native Swift checks and clean up
    /// after ourselves.
    static func attemptWrite(toPath path: String, content: String) -> Bool {
        JailbreakCheckUtils.canActuallyWrite(toPath: path, createIfMissing: true)
    }

    // MARK: - Process creation (backs native_CheckProcessCreation / "canFork")

    /// Stock iOS App Sandbox blocks `fork()` (returns -1, EOPNOTSUPP). On a
    /// jailbroken device the sandbox restriction is frequently missing/bypassed,
    /// so a *successful* fork is itself the compromise signal.
    static func canFork() -> Bool {
        // Skip while a debugger is attached: forking a process lldb is
        // tracing is unreliable and can wedge the debug session - that
        // failure mode is unrelated to sandbox integrity.
        if isDebuggerAttached() {
            return false
        }

        let pid = c_fork()
        if pid == 0 {
            // Child: exit immediately without touching the Swift/ObjC
            // runtime state we forked from.
            _exit(0)
        } else if pid > 0 {
            var status: Int32 = 0
            waitpid(pid, &status, 0)
            return true // fork() succeeded -> sandbox bypass
        }
        return false // fork() failed -> sandbox intact
    }

    // MARK: - System shell presence (backs native_CheckSystemShell)

    /// Returns `true` when NO shell binary is present (the safe/expected
    /// state on stock iOS). Naming mirrors the JS payload's inverted
    /// `runSystemShellChecks()` semantics.
    static func isSystemShellAbsent() -> Bool {
        let shellPaths = ["/bin/sh", "/bin/bash", "/bin/zsh"]
        return !shellPaths.contains { access($0, F_OK) == 0 }
    }

    // MARK: - Anti-debug (backs native_DisablePTrace)

    static func disablePTrace() {
        #if DEBUG
        // No-op in Debug builds so Xcode's debugger connection isn't
        // severed while developing/testing.
        #else
        c_ptrace(31 /* PT_DENY_ATTACH */, 0, nil, 0)
        #endif
    }
}
