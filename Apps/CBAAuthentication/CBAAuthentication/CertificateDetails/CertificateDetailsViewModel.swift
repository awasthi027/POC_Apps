//
//  CertificateDetailsViewModel.swift
//  CBAAuthentication
//
//  Created by Ashish Awasthi on 28/07/26.
//

import Foundation
internal import Combine
import Security

/// A single displayable attribute of a certificate.
struct CertificateDetailItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

/// View model responsible for extracting human-readable details from a `SecCertificate`
/// so they can be presented in `CertificateDetailsView`.
///
/// iOS does not expose the high-level `SecCertificateCopyValues` parsing API (macOS only),
/// so certificate fields such as issuer, subject, validity and key usage are extracted by
/// parsing the certificate's DER (ASN.1) representation with `X509CertificateParser`.
final class CertificateDetailsViewModel: ObservableObject {

    @Published private(set) var commonName: String
    @Published private(set) var subjectSummary: String
    @Published private(set) var issuer: String
    @Published private(set) var validFrom: String
    @Published private(set) var expiryDate: String
    @Published private(set) var serialNumber: String
    @Published private(set) var emails: String
    @Published private(set) var supportedOperations: String
    @Published private(set) var publicKeyInfo: String
    @Published private(set) var isExpired: Bool

    /// All details as a flat list, convenient for a `List`/`Form` presentation.
    var items: [CertificateDetailItem] {
        [
            CertificateDetailItem(title: "Certificate Name", value: commonName),
            CertificateDetailItem(title: "Subject", value: subjectSummary),
            CertificateDetailItem(title: "Issuer", value: issuer),
            CertificateDetailItem(title: "Valid From", value: validFrom),
            CertificateDetailItem(title: "Expiry Date", value: expiryDate),
            CertificateDetailItem(title: "Serial Number", value: serialNumber),
            CertificateDetailItem(title: "Email", value: emails),
            CertificateDetailItem(title: "Supported Operations", value: supportedOperations),
            CertificateDetailItem(title: "Public Key", value: publicKeyInfo)
        ]
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    init(certificate: SecCertificate?, fallbackName: String = "", label: String = "") {
        let placeholder = "—"

        guard let certificate else {
            commonName = fallbackName.isEmpty ? "(unknown certificate)" : fallbackName
            subjectSummary = placeholder
            issuer = placeholder
            validFrom = placeholder
            expiryDate = placeholder
            serialNumber = placeholder
            emails = placeholder
            supportedOperations = placeholder
            publicKeyInfo = placeholder
            isExpired = false
            return
        }

        // Common name / subject summary via high-level APIs available on iOS.
        var cn: CFString?
        SecCertificateCopyCommonName(certificate, &cn)
        let resolvedCommonName = (cn as String?) ?? fallbackName
        commonName = resolvedCommonName.isEmpty ? "(unknown certificate)" : resolvedCommonName
        subjectSummary = (SecCertificateCopySubjectSummary(certificate) as String?) ?? placeholder

        // Serial number.
        if let serialData = SecCertificateCopySerialNumberData(certificate, nil) as Data? {
            serialNumber = serialData.map { String(format: "%02X", $0) }.joined(separator: ":")
        } else {
            serialNumber = placeholder
        }

        // Parse the DER for issuer, subject, validity, key usage and email.
        let der = SecCertificateCopyData(certificate) as Data
        let parsed = X509CertificateParser(der: der).parse()

        if let subject = parsed?.subject, !subject.isEmpty {
            subjectSummary = subject
        }
        issuer = parsed?.issuer ?? placeholder

        if let notBefore = parsed?.notBefore {
            validFrom = CertificateDetailsViewModel.dateFormatter.string(from: notBefore)
        } else {
            validFrom = placeholder
        }
        if let notAfter = parsed?.notAfter {
            expiryDate = CertificateDetailsViewModel.dateFormatter.string(from: notAfter)
            isExpired = notAfter < Date()
        } else {
            expiryDate = placeholder
            isExpired = false
        }

        // Email addresses (prefer dedicated API, fall back to SAN from the parser).
        var emailArray: CFArray?
        SecCertificateCopyEmailAddresses(certificate, &emailArray)
        if let list = emailArray as? [String], !list.isEmpty {
            emails = list.joined(separator: ", ")
        } else if let sanEmails = parsed?.emails, !sanEmails.isEmpty {
            emails = sanEmails.joined(separator: ", ")
        } else {
            emails = placeholder
        }

        let operations = parsed?.supportedOperations ?? []
        supportedOperations = operations.isEmpty ? placeholder : operations.joined(separator: ", ")

        publicKeyInfo = CertificateDetailsViewModel.publicKeyDescription(for: certificate) ?? placeholder
    }

    private static func publicKeyDescription(for certificate: SecCertificate) -> String? {
        guard let key = SecCertificateCopyKey(certificate),
              let attributes = SecKeyCopyAttributes(key) as? [CFString: Any] else {
            return nil
        }

        let type = attributes[kSecAttrKeyType] as? String
        let sizeInBits = attributes[kSecAttrKeySizeInBits] as? Int

        let algorithm: String
        if type == (kSecAttrKeyTypeRSA as String) {
            algorithm = "RSA"
        } else if type == (kSecAttrKeyTypeECSECPrimeRandom as String) {
            algorithm = "EC"
        } else {
            algorithm = type ?? "Unknown"
        }

        if let sizeInBits {
            return "\(algorithm) (\(sizeInBits)-bit)"
        }
        return algorithm
    }
}
