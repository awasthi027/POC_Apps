//
//  CertificateListingViewModel.swift
//  SampleashiTokenApp
//
//  Copyright 2026 Ashi, Inc.
//  SPDX-License-Identifier: BSD-2-Clause
//

import UIKit
import Foundation
import Security
import CryptoTokenKit // To Handle error.
import CommonCrypto

import Foundation
internal import Combine

class CertificateObject: Identifiable {
    let id = UUID()
    /// Provides the certificate common name.
    var commonName : String? {
        guard let cert = self.certificate else {
            return ""
        }

        var cfName: CFString?
        SecCertificateCopyCommonName(cert, &cfName)
        return cfName as String?
    }

    /// certificate data.
    var certData: Data?

    /// x509 certificate detail.
    var certificate: SecCertificate?

    /// Hex-encoded serial number of the certificate.
    var serialNumber: String? {
        guard let cert = self.certificate,
              let serialData = SecCertificateCopySerialNumberData(cert, nil) as Data? else {
            return nil
        }
        return serialData.map { String(format: "%02x", $0) }.joined()
    }

    init(certificateData: Data) {
        self.certificate = SecCertificateCreateWithData(kCFAllocatorDefault, certificateData as CFData)
        self.certData = certificateData
    }
}

/// Define the potential error cases.
enum ErrorTypes: LocalizedError {
    case ashiAppLaunchNeeded(localisedDescription: String)
    case badInputData
    case signingError(localisedDescription: String)
    case verificationError
    case encryptionError
    case decryptionError(localisedDescription: String)
    case errorRetrievingKeys

    var localisedDescription: String {
        return self.localizedDescription
    }
}

/// Key operations performed.
enum KeyOperation: Int, CustomStringConvertible {
    case signAndVerify
    case encryptAndDecrypt

    var description: String {
        switch self {
        case .signAndVerify:
            return "Sign and Verify"
        case .encryptAndDecrypt:
            return "Encrypt and Decrypt"
        }
    }
}

/// Retrieved identity type.
enum IdentityType: Int {
    case signing
    case decryption
    case authentication
    case all
}

class CertificateListingViewModel: ObservableObject {
    /// Holds all requested identities.
    var allIdentities: [SecIdentity] = []
    /// Holds all selected identities.
    var selectedIdentities: [SecIdentity] = []
    /// Holds all certificates (x509).
    var allCertificates: [SecCertificate] = []

     init() {}

    /// local CertificateObjects
    @Published var certificates: [CertificateObject] = []

    //MARK: Data source methods
    var numberOfCertificates: Int {
        return self.certificates.count
    }


    func fetchCertificates(completion: (() -> Void)?) {
        getAllIdentities(identityType: .all, completion: completion)
    }

    /// Update selected identities for data source index.
    func updateSelectedIdentities(dataSourceIndex: Int) {
        guard self.allIdentities.count > dataSourceIndex else { return }
        
        let identity = self.allIdentities[dataSourceIndex]
        if let indexPresent = selectedIdentities.firstIndex(of: identity) {
            selectedIdentities.remove(at: indexPresent)
        }
        else {
            selectedIdentities.append(identity)
        }
    }

    func isIdentityAlreadySelected(dataSourceIndex: Int) -> Bool {
        let identity = self.allIdentities[dataSourceIndex]
        if let _ = selectedIdentities.firstIndex(of: identity) {
            return true
        }
        return false
    }

    func cleanupSelectedIdentities() {
        selectedIdentities.removeAll()
    }

    private func populateCertObjectsToDisplay(completion: (() -> Void)?) {
        certificates = []
        guard allIdentities.count > 0 else {
            print("[Consumer] No Identity found")
            completion?()
            return
        }

        print("[Consumer] Total identities for signing : \(allIdentities.count)")

        for ide in 0..<allIdentities.count {
            let identity: SecIdentity = allIdentities[ide] as SecIdentity
            var secCert: SecCertificate? = nil
            let status = SecIdentityCopyCertificate(identity, &secCert)
            if status != noErr {
                continue
            }
            print("[Consumer] Certificate identity fetch status : \(status)")

            guard let cert = secCert else {
                print("[Consumer] Certificate not found")
                return
            }

            let x509Cert = SecCertificateCopyData(cert) as Data
            certificates.append(CertificateObject(certificateData: x509Cert))
        }
        completion?()
    }



    /// Allows to get tokens from specific providers. for eg PIV-D only
    /// - Parameters:
    ///   - providers: provider list, If Provider list is empty then return all token id's
    /// - Returns: filter token id's list with provider list for bundle id availability
    internal func getFilteredIds(providers: [String]) -> [String] {
        var filtered: [String] = []
        let tokenIds = TKTokenWatcher().tokenIDs
        for token in providers {
            /// token id is consist of two parts - bundle id and base64 string.
            filtered.append(contentsOf: tokenIds.filter { $0.lowercased().contains(token.lowercased()) })
        }
        return filtered
    }

    //MARK:- Get all identities
    func getAllIdentities(identityType: IdentityType, completion: (() -> Void)?) {

        allIdentities = self.getAllTokens(type: identityType)

        // To get identities based on application provider. Eg: PIV-D manager
        // Uncomment below line and provide specific app ctk provider name.
        // allIdentities = self.getFilteredTokens(type: identityType, providers: ["com.air-watch.ashi.ashitoken"])

        populateCertObjectsToDisplay(completion: completion)
    }

    /// Generic query for fetching data from keychain based on type
    /// - Parameters:
    ///   - type: DataType: TokenType should be provided, default is all
    /// - Returns:query to be used for fetching data
    func tokenBasedQuery(type: IdentityType) -> [CFString: Any] {
        var query:[CFString: Any] = [:]
        query[kSecReturnRef] = kCFBooleanTrue
        query[kSecClass] = kSecClassIdentity
        query[kSecAttrAccessGroup] = kSecAttrAccessGroupToken

        switch type {
        case .authentication:
            /// Use application tag to identify the authentication certificate
            /// iOS provides queries to identify the sign and encrypt tokens but doesn't provide a way to identify auth tokens. For instance, If there are two tokens for signing and authentication CTK consumers won't be able to differentiate b/w those tokens. If CTKPovider can pass some info along with auth token to identify consumers can be resolved by adding query info to retrieve tokens.

            // query[kSecAttrApplicationTag] = "authentication".data(using: .utf8)
            break
            ///
        case .signing:
            /// filter to fetch only signing capability identities
            query[kSecAttrCanSign] = kCFBooleanTrue
        case .decryption:
            /// filter to fetch only encryption/decryption capability identities
            query[kSecAttrCanDecrypt] = kCFBooleanTrue
        default: break
            /// No specific query item needed to filter all type of identities.
        }
        return query
    }

    /// Fetch token id specific data from keychain
    /// - Parameters:
    ///   - query: Query to be used for fetch data
    ///   - providers: Providers list to be used for filter token id
    /// - Returns: SecIdentity Array to fetch certificate
    internal func getFilteredTokens(type: IdentityType, providers: [String]) -> [SecIdentity] {
        var identities: [SecIdentity] = []
        var query = tokenBasedQuery(type: type)
        for tokenID in getFilteredIds(providers: providers) {
            /// Fetch data based on tokenID
            query[kSecAttrTokenID] = tokenID as AnyObject?
            /// copy items from keychain
            var rawData: AnyObject?
            let result = SecItemCopyMatching(query as CFDictionary, &rawData)
            if result == noErr,
               let unwrapData = rawData,
               CFGetTypeID(unwrapData) == SecIdentityGetTypeID() {
                let identity = unwrapData as! SecIdentity
                identities.append(identity)
            } else{
                print("[Consumer] Error while collecting identities, error : \(result.secErrorMessage)")
            }
        }
        return identities
    }

    /// Fetch all list from keychain
    /// - Parameters:
    ///   - query: Query to be used for fetch data
    /// - Returns: SecIdentity Array to fetch certificate
    internal func getAllTokens(type: IdentityType) -> [SecIdentity] {
        print("[Consumer] Providers list is empty, so fetching all persistent token id's from keychain")
        var query = tokenBasedQuery(type: type)
        // fetch all data identities
        query[kSecMatchLimit] = kSecMatchLimitAll
        // copy items from keychain
        var rawData: AnyObject?
        let result = SecItemCopyMatching(query as CFDictionary, &rawData)
        guard result == noErr, rawData != nil, let ids = rawData as? [SecIdentity], ids.isEmpty == false else {
            print("[Consumer] Error while collecting identities for empty provider list \(result.secErrorMessage)")
            return []
        }
        return ids
    }
}

extension OSStatus {
    var secErrorMessage: String {
        return (SecCopyErrorMessageString(self, nil) as String?) ?? "\(self)"
    }
}

extension UIDevice {
    var isIPad : Bool {
        return userInterfaceIdiom == .pad
    }
}
