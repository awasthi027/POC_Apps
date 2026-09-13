//
//  main.swift
//  LearningDaemon
//
//  A real launchd-managed daemon: a plain executable (not an app, not an
//  .xpc bundle) that vends a Mach service and runs for as long as launchd
//  keeps it around, independent of any client app.
//
//  Contrast with the sibling XPC demo (MacOSConcepts/ImageParserService):
//  that XPC Service is started on demand by launchd for one conversation and
//  can idle-exit when nobody's connected. This daemon, once installed with
//  RunAtLoad + KeepAlive, stays resident and launchd relaunches it if it
//  ever dies — that's the property that makes it a "daemon" rather than a
//  service.
//

import Foundation

let launchTime = Date()
var jobCount = 0

let logURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Logs/LearningDaemon.log")

func log(_ message: String) {
    let line = "[\(Date())] [pid \(getpid())] \(message)\n"
    print(line, terminator: "")
    guard let data = line.data(using: .utf8) else { return }
    if let handle = try? FileHandle(forWritingTo: logURL) {
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
    } else {
        try? data.write(to: logURL)
    }
}

final class LearningDaemonService: NSObject, LearningDaemonProtocol {
    func ping(withReply reply: @escaping (Int32, Double, Int) -> Void) {
        let uptime = Date().timeIntervalSince(launchTime)
        log("ping — uptime \(Int(uptime))s, jobCount \(jobCount)")
        reply(getpid(), uptime, jobCount)
    }

    // Not synchronized with a lock: this demo is single-threaded via
    // NSXPCListener's default serial delivery, so plain increment is safe.
    func submitJob(from workerName: String, withReply reply: @escaping (Int, Int32) -> Void) {
        jobCount += 1
        log("job #\(jobCount) submitted by worker '\(workerName)'")
        reply(jobCount, getpid())
    }

    func crashDaemon() {
        log("crashDaemon() called — exiting now; launchd should relaunch me if KeepAlive is set")
        exit(1)
    }
}

final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    // One shared instance handed to every connection, so state (jobCount)
    // is shared across all workers, not per-client.
    let service = LearningDaemonService()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: LearningDaemonProtocol.self)
        newConnection.exportedObject = service
        newConnection.invalidationHandler = { log("a client connection was invalidated") }
        newConnection.resume()
        log("accepted connection from client pid \(newConnection.processIdentifier)")
        return true
    }
}

log("LearningDaemon starting up")

let delegate = ListenerDelegate()
let listener = NSXPCListener(machServiceName: "ashi.newLearning.LearningDaemon")
listener.delegate = delegate
listener.resume()

log("listening on Mach service ashi.newLearning.LearningDaemon")

RunLoop.main.run()
