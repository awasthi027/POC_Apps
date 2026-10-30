import Foundation

struct IdentitySnapshot: Sendable, Equatable {
    var anonymousID: String
    var userID: String?
}

/// Validates, enriches and encodes events. Pure and synchronous: no I/O, no suspension, safe to call under a lock.
struct EventProcessor: Sendable {
    let limits: EventLimits
    let piiPolicy: PIIPolicy
    let contextProvider: any ContextProvider

    /// Substrings that mark a property key as likely sensitive. Heuristic guard rail, not a PII detector.
    private static let sensitiveKeyFragments = ["password", "passwd", "secret", "token", "ssn", "credit_card",
                                                "creditcard", "card_number", "cardnumber", "cvv", "api_key", "apikey"]

    /// - Parameter allowReserved: SDK-generated names/keys may start with `$`; caller-supplied ones may not.
    func validate(name: String, properties: [String: AnalyticsValue], allowReservedName: Bool) throws {
        guard Self.isIdentifier(name, maxBytes: limits.maxNameLength, allowReserved: allowReservedName) else {
            throw AnalyticsError.validation(name.hasPrefix("$") ? .reservedName : .invalidName, key: nil)
        }
        guard properties.count <= limits.maxProperties else { throw AnalyticsError.validation(.tooManyProperties, key: nil) }
        for (key, value) in properties {
            guard Self.isIdentifier(key, maxBytes: limits.maxKeyLength, allowReserved: false) else {
                throw AnalyticsError.validation(key.hasPrefix("$") ? .reservedPropertyKey : .invalidPropertyKey, key: String(key.prefix(limits.maxKeyLength)))
            }
            if piiPolicy == .rejectSuspected {
                let lower = key.lowercased()
                if Self.sensitiveKeyFragments.contains(where: lower.contains) { throw AnalyticsError.validation(.possiblePII, key: key) }
            }
            switch value {
            case .string(let s):
                guard s.utf8.count <= limits.maxStringValueBytes else { throw AnalyticsError.validation(.stringValueTooLong, key: key) }
                if piiPolicy == .rejectSuspected && Self.looksLikeEmail(s) { throw AnalyticsError.validation(.possiblePII, key: key) }
            case .double(let d):
                guard d.isFinite else { throw AnalyticsError.validation(.nonFiniteNumber, key: key) }
            case .int, .bool:
                break
            }
        }
    }

    func validate(userID: String) throws {
        guard !userID.isEmpty, userID.utf8.count <= 256 else { throw AnalyticsError.validation(.invalidUserID, key: nil) }
        if piiPolicy == .rejectSuspected && Self.looksLikeEmail(userID) { throw AnalyticsError.validation(.possiblePII, key: nil) }
    }

    /// Assigns context + identity and encodes. `eventID` is supplied by the caller and is the ONLY ID this event
    /// will ever have: it is persisted in the payload and column, so every retry re-sends the same ID.
    func makeEvent(eventID: String, name: String, properties: [String: AnalyticsValue], timestamp: Date,
                   sessionID: String, identity: IdentitySnapshot) throws -> PersistableEvent {
        let event = AnalyticsEvent(eventID: eventID, name: name, timestamp: timestamp, sessionID: sessionID,
                                   anonymousID: identity.anonymousID, userID: identity.userID, properties: properties,
                                   context: contextProvider.currentContext(), schemaVersion: AnalyticsSDKInfo.eventSchemaVersion)
        let payload = try WireFormat.makeEncoder().encode(event)
        guard payload.count <= limits.maxEventBytes else { throw AnalyticsError.validation(.eventTooLarge, key: nil) }
        return PersistableEvent(eventID: eventID, createdAt: timestamp, payload: payload)
    }

    private static func isIdentifier(_ s: String, maxBytes: Int, allowReserved: Bool) -> Bool {
        guard !s.isEmpty, s.utf8.count <= maxBytes else { return false }
        for (i, scalar) in s.unicodeScalars.enumerated() {
            let letter = (scalar.value >= 65 && scalar.value <= 90) || (scalar.value >= 97 && scalar.value <= 122)
            let digit = scalar.value >= 48 && scalar.value <= 57
            let punctuation = scalar == "_" || scalar == "." || scalar == "-" || scalar == " "
            if i == 0 { guard letter || (allowReserved && scalar == "$") else { return false } }
            else { guard letter || digit || punctuation else { return false } }
        }
        return true
    }

    private static func looksLikeEmail(_ s: String) -> Bool {
        guard s.contains("@") else { return false }
        return s.split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == ";" }).contains { token in
            let parts = token.split(separator: "@", omittingEmptySubsequences: false)
            return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".") && !parts[1].hasSuffix(".") && !parts[1].hasPrefix(".")
        }
    }
}
