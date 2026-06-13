import Foundation

/// Holds all shared networking config so URLSession is configured in one place.
final class SecureNetworkEnvironment {
    static let shared = SecureNetworkEnvironment()

    let baseURL = "https://localhost:8443"
    let deviceId = "device-123"
    let session: URLSession

    private init() {
        let delegate = MTLSDelegate(p12Name: "client", p12Password: "client-secret")
        session = URLSession(configuration: .default, delegate: delegate, delegateQueue: .main)
    }
}

