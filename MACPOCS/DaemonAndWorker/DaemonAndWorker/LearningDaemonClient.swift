//
//  LearningDaemonClient.swift
//  DaemonAndWorker
//
//  The app is one of potentially many "workers" — separate processes that
//  all connect to the same long-running daemon by its Mach service name.
//  Launching this app twice (or running a second tiny client) would give
//  you two independent NSXPCConnections to the exact same daemon process,
//  sharing its jobCount state.
//

import Foundation

final class LearningDaemonClient {
    static let machServiceName = "ashi.newLearning.LearningDaemon"

    private var connection: NSXPCConnection?

    private func proxy(errorHandler: @escaping (Error) -> Void) -> LearningDaemonProtocol? {
        if connection == nil {
            let c = NSXPCConnection(machServiceName: Self.machServiceName, options: [])
            c.remoteObjectInterface = NSXPCInterface(with: LearningDaemonProtocol.self)
            c.invalidationHandler = { [weak self] in self?.connection = nil }
            c.interruptionHandler = { [weak self] in self?.connection = nil }
            c.resume()
            connection = c
        }
        return connection?.remoteObjectProxyWithErrorHandler(errorHandler) as? LearningDaemonProtocol
    }

    func ping(completion: @escaping (Result<(pid: Int32, uptime: Double, jobCount: Int), Error>) -> Void) {
        let proxy = proxy { error in completion(.failure(error)) }
        proxy?.ping { pid, uptime, jobCount in
            completion(.success((pid, uptime, jobCount)))
        }
    }

    func submitJob(workerName: String, completion: @escaping (Result<(jobNumber: Int, pid: Int32), Error>) -> Void) {
        let proxy = proxy { error in completion(.failure(error)) }
        proxy?.submitJob(from: workerName) { jobNumber, pid in
            completion(.success((jobNumber, pid)))
        }
    }

    func crashDaemon() {
        let proxy = proxy { _ in }
        proxy?.crashDaemon()
    }
}
