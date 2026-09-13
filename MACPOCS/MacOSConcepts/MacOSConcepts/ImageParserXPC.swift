//
//  ImageParserXPC.swift
//  MacOSConcepts
//
//  App-side client for the ImageParserService XPC Service target. The
//  protocol type (ImageParserServiceProtocol) comes from
//  ImageParserService/ImageParserServiceProtocol.swift — that file must
//  also be a member of this target (File Inspector > Target Membership)
//  so both processes agree on the exact same wire interface.
//

import Foundation

final class ImageParserClient {
    private let connection: NSXPCConnection

    init(onCrash: @escaping () -> Void) {
        connection = NSXPCConnection(serviceName: "ashi.com.newLearning.ImageParserService")
        connection.remoteObjectInterface = NSXPCInterface(with: (any ImageParserServiceProtocol).self)
        // Fires when the service process dies mid-connection (e.g. our
        // simulated crash) — this is how the host app finds out without
        // going down itself.
        connection.interruptionHandler = {
            DispatchQueue.main.async(execute: onCrash)
        }
        connection.resume()
    }

    func parseImage(_ data: Data, completion: @escaping (Int, Int) -> Void) {
        let proxy = connection.remoteObjectProxyWithErrorHandler { _ in
            completion(0, 0)
        } as! ImageParserServiceProtocol
        proxy.parseImage(data, withReply: completion)
    }

    func invalidate() {
        connection.invalidate()
    }
}

enum ImageParserXPCDemo {
    private static var client: ImageParserClient?

    static func parseImage(
        _ data: Data,
        onCrash: @escaping () -> Void,
        completion: @escaping (Int, Int) -> Void
    ) {
        let client = ImageParserClient(onCrash: onCrash)
        self.client = client
        client.parseImage(data, completion: completion)
    }
}
