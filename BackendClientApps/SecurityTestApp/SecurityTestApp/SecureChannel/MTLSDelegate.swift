
import Foundation
import Security

final class MTLSDelegate: NSObject, URLSessionDelegate {
    private let p12Name: String
    private let p12Password: String

    init(p12Name: String, p12Password: String) {
        self.p12Name = p12Name
        self.p12Password = p12Password
    }

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        let method = challenge.protectionSpace.authenticationMethod
        if method == NSURLAuthenticationMethodServerTrust {
            guard let serverTrust = challenge.protectionSpace.serverTrust else {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }

            // Learning mode: accept the server trust as presented.
            // Safer option is to validate against CA or pin the cert.
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
            return
        }

        if method == NSURLAuthenticationMethodClientCertificate {
            guard
                let url = Bundle.main.url(forResource: p12Name, withExtension: "p12"),
                let p12Data = try? Data(contentsOf: url)
            else {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }
            
            let options = [kSecImportExportPassphrase as String: p12Password]
            var items: CFArray?

            let status = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &items)
            guard status == errSecSuccess,
                  let array = items as? [[String: Any]],
                  let first = array.first,
                  let identityRef = first[kSecImportItemIdentity as String]
            else {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }

            guard CFGetTypeID(identityRef as CFTypeRef) == SecIdentityGetTypeID() else {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }

            let identity = identityRef as! SecIdentity

            let credential = URLCredential(identity: identity, certificates: nil, persistence: .forSession)
            completionHandler(.useCredential, credential)
            return
        }

        completionHandler(.performDefaultHandling, nil)
    }
}
