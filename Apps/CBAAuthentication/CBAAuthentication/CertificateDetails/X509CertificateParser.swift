//
//  X509CertificateParser.swift
//  CBAAuthentication
//
//  Created by Ashish Awasthi on 28/07/26.
//
//  A minimal ASN.1 DER parser that extracts the certificate fields iOS does not expose
//  through the Security framework (issuer, subject, validity dates, key usage, SAN emails).
//

import Foundation

/// Parsed representation of the interesting parts of an X.509 certificate.
struct ParsedCertificate {
    var subject: String?
    var issuer: String?
    var notBefore: Date?
    var notAfter: Date?
    var emails: [String]
    var supportedOperations: [String]
}

/// Very small, self-contained X.509 (RFC 5280) DER parser tailored to the fields we display.
final class X509CertificateParser {

    private let bytes: [UInt8]

    init(der: Data) {
        self.bytes = [UInt8](der)
    }

    // MARK: - ASN.1 primitives

    private struct TLV {
        let tag: UInt8
        let valueRange: Range<Int>   // range of the content bytes
        let endIndex: Int            // index just past this TLV
    }

    /// Reads a single TLV starting at `index`.
    private func readTLV(at index: Int) -> TLV? {
        guard index < bytes.count else { return nil }
        let tag = bytes[index]
        var cursor = index + 1
        guard cursor < bytes.count else { return nil }

        var length = 0
        let first = bytes[cursor]
        cursor += 1
        if first & 0x80 == 0 {
            length = Int(first)
        } else {
            let numBytes = Int(first & 0x7F)
            guard numBytes > 0, cursor + numBytes <= bytes.count else { return nil }
            for _ in 0..<numBytes {
                length = (length << 8) | Int(bytes[cursor])
                cursor += 1
            }
        }

        let valueStart = cursor
        let valueEnd = valueStart + length
        guard valueEnd <= bytes.count else { return nil }
        return TLV(tag: tag, valueRange: valueStart..<valueEnd, endIndex: valueEnd)
    }

    /// Iterates the child TLVs contained within `range`.
    private func children(in range: Range<Int>) -> [TLV] {
        var result: [TLV] = []
        var index = range.lowerBound
        while index < range.upperBound {
            guard let tlv = readTLV(at: index) else { break }
            result.append(tlv)
            index = tlv.endIndex
        }
        return result
    }

    // MARK: - Public entry

    func parse() -> ParsedCertificate? {
        // Certificate ::= SEQUENCE { tbsCertificate, signatureAlgorithm, signatureValue }
        guard let certificate = readTLV(at: 0), certificate.tag == 0x30,
              let tbs = readTLV(at: certificate.valueRange.lowerBound), tbs.tag == 0x30 else {
            return nil
        }

        var fields = children(in: tbs.valueRange)
        guard !fields.isEmpty else { return nil }

        // Optional version [0] EXPLICIT (context tag 0xA0) precedes serialNumber.
        var cursor = 0
        if fields[cursor].tag == 0xA0 {
            cursor += 1
        }

        // Order: serialNumber, signature(AlgId), issuer, validity, subject, subjectPublicKeyInfo, ...
        // serialNumber (INTEGER)
        cursor += 1
        guard cursor < fields.count else { return nil }
        // signature AlgorithmIdentifier (SEQUENCE)
        cursor += 1
        guard cursor < fields.count else { return nil }

        // issuer Name (SEQUENCE)
        let issuerTLV = fields[cursor]; cursor += 1
        // validity (SEQUENCE of two Time)
        guard cursor < fields.count else { return nil }
        let validityTLV = fields[cursor]; cursor += 1
        // subject Name (SEQUENCE)
        guard cursor < fields.count else { return nil }
        let subjectTLV = fields[cursor]; cursor += 1

        let issuer = distinguishedName(from: issuerTLV)
        let subject = distinguishedName(from: subjectTLV)
        let (notBefore, notAfter) = validity(from: validityTLV)

        // Extensions live in [3] EXPLICIT at the end of the TBS.
        var emails: [String] = []
        var operations: [String] = []
        if cursor < fields.count {
            // Skip subjectPublicKeyInfo (already at cursor). Advance past it.
            // Remaining fields may include issuerUniqueID [1], subjectUniqueID [2], extensions [3].
            for tlv in fields[cursor...] where tlv.tag == 0xA3 {
                if let extensionsSeq = readTLV(at: tlv.valueRange.lowerBound), extensionsSeq.tag == 0x30 {
                    let (e, ops) = parseExtensions(extensionsSeq)
                    emails = e
                    operations = ops
                }
            }
        }

        return ParsedCertificate(subject: subject,
                                 issuer: issuer,
                                 notBefore: notBefore,
                                 notAfter: notAfter,
                                 emails: emails,
                                 supportedOperations: operations)
    }

    // MARK: - Distinguished Name

    private func distinguishedName(from tlv: TLV) -> String? {
        // Name ::= SEQUENCE OF RelativeDistinguishedName (SET OF AttributeTypeAndValue)
        var components: [String] = []
        for rdn in children(in: tlv.valueRange) where rdn.tag == 0x31 {
            for atv in children(in: rdn.valueRange) where atv.tag == 0x30 {
                let parts = children(in: atv.valueRange)
                guard parts.count >= 2, parts[0].tag == 0x06 else { continue }
                let oid = objectIdentifier(parts[0])
                let value = string(from: parts[1])
                if let short = X509CertificateParser.shortLabel(for: oid), !value.isEmpty {
                    components.append("\(short)=\(value)")
                } else if !value.isEmpty {
                    components.append(value)
                }
            }
        }
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }

    // MARK: - Validity

    private func validity(from tlv: TLV) -> (Date?, Date?) {
        let times = children(in: tlv.valueRange)
        guard times.count >= 2 else { return (nil, nil) }
        return (date(from: times[0]), date(from: times[1]))
    }

    private func date(from tlv: TLV) -> Date? {
        let raw = string(from: tlv)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        // UTCTime (tag 0x17) uses 2-digit year, GeneralizedTime (tag 0x18) uses 4-digit year.
        formatter.dateFormat = tlv.tag == 0x18 ? "yyyyMMddHHmmss'Z'" : "yyMMddHHmmss'Z'"
        return formatter.date(from: raw)
    }

    // MARK: - Extensions

    private func parseExtensions(_ extensionsSeq: TLV) -> ([String], [String]) {
        var emails: [String] = []
        var operations: [String] = []

        for ext in children(in: extensionsSeq.valueRange) where ext.tag == 0x30 {
            let parts = children(in: ext.valueRange)
            guard let oidTLV = parts.first, oidTLV.tag == 0x06 else { continue }
            let oid = objectIdentifier(oidTLV)
            // The extnValue OCTET STRING is the last element (after optional critical BOOLEAN).
            guard let octet = parts.last(where: { $0.tag == 0x04 }) else { continue }

            switch oid {
            case "2.5.29.15": // keyUsage
                operations.append(contentsOf: keyUsage(from: octet))
            case "2.5.29.37": // extendedKeyUsage
                operations.append(contentsOf: extendedKeyUsage(from: octet))
            case "2.5.29.17": // subjectAltName
                emails.append(contentsOf: subjectAltNameEmails(from: octet))
            default:
                break
            }
        }
        return (emails, operations)
    }

    private func keyUsage(from octet: TLV) -> [String] {
        guard let bitString = readTLV(at: octet.valueRange.lowerBound), bitString.tag == 0x03 else {
            return []
        }
        // First content byte of a BIT STRING is the count of unused bits.
        let content = Array(bytes[bitString.valueRange])
        guard content.count >= 2 else { return [] }
        let flags = content[1]
        let usageMap: [(UInt8, String)] = [
            (0x80, "Digital Signature"),
            (0x40, "Non-Repudiation"),
            (0x20, "Key Encipherment"),
            (0x10, "Data Encipherment"),
            (0x08, "Key Agreement"),
            (0x04, "Certificate Signing"),
            (0x02, "CRL Signing"),
            (0x01, "Encipher Only")
        ]
        return usageMap.compactMap { flags & $0.0 != 0 ? $0.1 : nil }
    }

    private func extendedKeyUsage(from octet: TLV) -> [String] {
        guard let seq = readTLV(at: octet.valueRange.lowerBound), seq.tag == 0x30 else { return [] }
        let ekuMap: [String: String] = [
            "1.3.6.1.5.5.7.3.1": "Server Authentication",
            "1.3.6.1.5.5.7.3.2": "Client Authentication",
            "1.3.6.1.5.5.7.3.3": "Code Signing",
            "1.3.6.1.5.5.7.3.4": "Email Protection",
            "1.3.6.1.5.5.7.3.8": "Time Stamping"
        ]
        return children(in: seq.valueRange).compactMap { tlv in
            guard tlv.tag == 0x06 else { return nil }
            let oid = objectIdentifier(tlv)
            return ekuMap[oid] ?? oid
        }
    }

    private func subjectAltNameEmails(from octet: TLV) -> [String] {
        guard let seq = readTLV(at: octet.valueRange.lowerBound), seq.tag == 0x30 else { return [] }
        // rfc822Name is context-specific tag [1] (0x81).
        return children(in: seq.valueRange).compactMap { tlv in
            guard tlv.tag == 0x81 else { return nil }
            return String(bytes: bytes[tlv.valueRange], encoding: .utf8)
        }
    }

    // MARK: - Value decoding

    private func string(from tlv: TLV) -> String {
        String(bytes: bytes[tlv.valueRange], encoding: .utf8)
            ?? String(bytes: bytes[tlv.valueRange], encoding: .ascii)
            ?? ""
    }

    private func objectIdentifier(_ tlv: TLV) -> String {
        let content = Array(bytes[tlv.valueRange])
        guard !content.isEmpty else { return "" }
        var components: [Int] = []
        let first = Int(content[0])
        components.append(first / 40)
        components.append(first % 40)

        var value = 0
        for byte in content[1...] {
            value = (value << 7) | Int(byte & 0x7F)
            if byte & 0x80 == 0 {
                components.append(value)
                value = 0
            }
        }
        return components.map(String.init).joined(separator: ".")
    }

    private static func shortLabel(for oid: String) -> String? {
        switch oid {
        case "2.5.4.3": return "CN"
        case "2.5.4.10": return "O"
        case "2.5.4.11": return "OU"
        case "2.5.4.6": return "C"
        case "2.5.4.7": return "L"
        case "2.5.4.8": return "ST"
        case "1.2.840.113549.1.9.1": return "E"
        default: return nil
        }
    }
}
