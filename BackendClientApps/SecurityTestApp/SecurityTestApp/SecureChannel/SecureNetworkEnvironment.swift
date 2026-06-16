import Foundation
/// Holds all shared networking config so URLSession is configured in one place.
final class SecureNetworkEnvironment {
    static let shared = SecureNetworkEnvironment()
    let baseURL = "https://secure-channel-service-production.up.railway.app"
    //let baseURL = "https://localhost:8443" //

    let deviceId = "device-123"
    let deviceIdentityHeader = "X-Device-Id"
    let session: URLSession
    private init() {
        let delegate = MTLSDelegate(p12Name: "client", p12Password: "client-secret")
        session = URLSession(configuration: .default, delegate: delegate, delegateQueue: .main)
    }
}
