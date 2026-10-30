import Foundation

/// Permitted environment metadata attached to every event. Deliberately excludes advertising identifiers,
/// precise location, contacts, and any hardware identifier.
public struct EventContext: Codable, Sendable, Equatable {
    public var appVersion: String
    public var appBuild: String
    public var osName: String
    public var osVersion: String
    public var deviceModel: String
    public var locale: String
    public var timeZone: String
    public var networkType: String?
    public var sdkVersion: String

    enum CodingKeys: String, CodingKey {
        case appVersion = "app_version", appBuild = "app_build", osName = "os_name", osVersion = "os_version"
        case deviceModel = "device_model", locale, timeZone = "time_zone", networkType = "network_type"
        case sdkVersion = "sdk_version"
    }
}

/// The wire/storage representation of one event. The JSON encoding of this struct is stored verbatim in the
/// queue and sent verbatim to the server, so retries are byte-identical and batch size is exact.
///
/// Identity is captured at creation time and never rewritten afterwards.
public struct AnalyticsEvent: Codable, Sendable, Equatable {
    public var eventID: String
    public var name: String
    public var timestamp: Date
    public var sessionID: String
    public var anonymousID: String
    public var userID: String?
    public var properties: [String: AnalyticsValue]
    public var context: EventContext
    public var schemaVersion: Int

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id", name = "event_name", timestamp, sessionID = "session_id"
        case anonymousID = "anonymous_id", userID = "user_id", properties, context
        case schemaVersion = "schema_version"
    }
}

enum WireFormat {
    static func timestampString(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }

    /// Sorted keys make the stored bytes deterministic (testable, cache- and diff-friendly).
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, enc in
            var c = enc.singleValueContainer()
            try c.encode(WireFormat.timestampString(date))
        }
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { dec in
            let s = try dec.singleValueContainer().decode(String.self)
            guard let d = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(s) else {
                throw DecodingError.dataCorrupted(.init(codingPath: dec.codingPath, debugDescription: "bad timestamp"))
            }
            return d
        }
        return decoder
    }
}
