//
//  LearningDaemonProtocol.swift
//
//  The wire contract between the daemon and every client (worker) that talks
//  to it. This exact file must exist, byte-for-byte, on both sides:
//    - here, compiled into the LearningDaemon executable
//    - copied into DaemonAndWorker/DaemonAndWorker/ so Xcode's synchronized
//      folder picks it up for the app target
//  XPC has no shared header/compiler check across processes, so if the two
//  copies drift, calls will fail or silently mismatch at runtime.
//

import Foundation

@objc protocol LearningDaemonProtocol {
    /// Health check — proves the daemon is alive and shows how long it has
    /// been running independent of any client app's lifetime.
    func ping(withReply reply: @escaping (_ pid: Int32, _ uptimeSeconds: Double, _ jobCount: Int) -> Void)

    /// Simulates a worker handing off a unit of work. jobCount is shared
    /// state on the daemon side, so calls from different workers (or
    /// different launches of the app) all increment the same counter.
    func submitJob(from workerName: String, withReply reply: @escaping (_ jobNumber: Int, _ handledByPID: Int32) -> Void)

    /// Deliberately terminates the daemon process to demonstrate launchd's
    /// KeepAlive restart behavior.
    func crashDaemon()
}
