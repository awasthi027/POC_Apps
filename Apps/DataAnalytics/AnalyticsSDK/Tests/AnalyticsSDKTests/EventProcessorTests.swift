import Foundation
import Testing
@testable import AnalyticsSDK

@Suite final class EventProcessorTests {
    private let identity = IdentitySnapshot(anonymousID: "anon-1", userID: nil)

    private func processor(_ mutate: (inout EventLimits) -> Void = { _ in }, pii: PIIPolicy = .rejectSuspected) -> EventProcessor {
        var limits = EventLimits(); mutate(&limits)
        return EventProcessor(limits: limits, piiPolicy: pii, contextProvider: FixedContextProvider())
    }

    private func assertRejected(_ name: String, _ props: [String: AnalyticsValue] = [:], reason: ValidationFailure,
                                p: EventProcessor? = nil) {
        do {
            try (p ?? processor()).validate(name: name, properties: props, allowReservedName: false)
            Issue.record("expected \(reason) but validation passed")
        } catch {
            guard case AnalyticsError.validation(let failure, _) = error else { return fail("wrong error \(error)") }
            #expect(failure == reason)
        }
    }

    @Test func validatesNamesAndProperties() {
        assertRejected("", reason: .invalidName)
        assertRejected("1starts_with_digit", reason: .invalidName)
        assertRejected("has/slash", reason: .invalidName)
        assertRejected(String(repeating: "a", count: 65), reason: .invalidName)
        assertRejected("$session_start", reason: .reservedName)                      // reserved for the SDK
        assertRejected("ok", ["$internal": 1], reason: .reservedPropertyKey)
        assertRejected("ok", ["bad key!": 1], reason: .invalidPropertyKey)
        assertRejected("ok", ["nan": .double(.nan)], reason: .nonFiniteNumber)
        assertRejected("ok", ["long": .string(String(repeating: "x", count: 2000))], reason: .stringValueTooLong)
        let many = Dictionary(uniqueKeysWithValues: (0..<51).map { ("k\($0)", AnalyticsValue.int($0)) })
        assertRejected("ok", many, reason: .tooManyProperties)
        #expect(throws: Never.self) { _ = try processor().validate(name: "product_viewed", properties: ["product_id": "123", "price": 9.5, "in_stock": true], allowReservedName: false) }
    }

    @Test func piiGuardRailsRejectSuspectedValuesAndKeysButCanBeDisabled() {
        assertRejected("ok", ["contact": "jane@example.com"], reason: .possiblePII)
        assertRejected("ok", ["note": "reach me at jane@example.com please"], reason: .possiblePII)
        assertRejected("ok", ["user_password": "x"], reason: .possiblePII)
        assertRejected("ok", ["Auth_Token": "x"], reason: .possiblePII)
        #expect(throws: Never.self) { _ = try processor().validate(name: "ok", properties: ["handle": "@jane"], allowReservedName: false) }   // not an e-mail
        #expect(throws: Never.self) { _ = try processor(pii: .off).validate(name: "ok", properties: ["contact": "jane@example.com"], allowReservedName: false) }
    }

    @Test func validationErrorsNeverContainPropertyValues() {
        do { try processor().validate(name: "ok", properties: ["contact": "jane@example.com"], allowReservedName: false); Issue.record("failed") }
        catch { #expect(!("\(error)".contains("jane@example.com"))) }
    }

    @Test func eventIDIsStableAndPayloadIsDeterministic() throws {
        let p = processor()
        let t = Date(timeIntervalSince1970: 1_800_000_000.123)
        let a = try p.makeEvent(eventID: "e-1", name: "viewed", properties: ["b": 2, "a": 1], timestamp: t, sessionID: "s", identity: identity)
        let b = try p.makeEvent(eventID: "e-1", name: "viewed", properties: ["a": 1, "b": 2], timestamp: t, sessionID: "s", identity: identity)
        #expect(a.eventID == "e-1")
        #expect(a.payload == b.payload, "sorted keys → byte-identical regardless of dictionary order")
        let decoded = try WireFormat.makeDecoder().decode(AnalyticsEvent.self, from: a.payload)
        #expect(decoded.eventID == "e-1")
        #expect(abs((decoded.timestamp.timeIntervalSince1970) - (1_800_000_000.123)) <= 0.001)
    }

    @Test func contextAndIdentityEnrichment() throws {
        let e = try processor().makeEvent(eventID: "e", name: "n", properties: [:], timestamp: Date(), sessionID: "sess-9",
                                          identity: IdentitySnapshot(anonymousID: "anon-7", userID: "user-5"))
        let decoded = try WireFormat.makeDecoder().decode(AnalyticsEvent.self, from: e.payload)
        #expect(decoded.context.appVersion == "1.2.3")
        #expect(decoded.context.sdkVersion == AnalyticsSDKInfo.version)
        #expect(decoded.sessionID == "sess-9")
        #expect(decoded.anonymousID == "anon-7")
        #expect(decoded.userID == "user-5")
        #expect(decoded.schemaVersion == AnalyticsSDKInfo.eventSchemaVersion)
        let json = String(data: e.payload, encoding: .utf8) ?? ""
        #expect(!(json.contains("idfa")), "no advertising identifier")
    }

    @Test func oversizedEventIsRejected() {
        let p = processor { $0.maxEventBytes = 300 }
        #expect(throws: AnalyticsError.validation(.eventTooLarge, key: nil)) {
            try p.makeEvent(eventID: "e", name: "n", properties: ["k": .string(String(repeating: "x", count: 500))],
                            timestamp: Date(), sessionID: "s", identity: identity)
        }
    }

    @Test func retryAfterParsing() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(RetryAfter.parse("120", now: now) == 120)
        #expect(RetryAfter.parse("-5", now: now) == nil)
        #expect(RetryAfter.parse("soon", now: now) == nil)
        #expect(RetryAfter.parse(nil, now: now) == nil)
        // 1_800_000_000 is 2027-01-15 08:00:00 UTC, so this HTTP-date is exactly 90s ahead of `now - 90`.
        #expect(RetryAfter.parse("Fri, 15 Jan 2027 08:00:00 GMT", now: now.addingTimeInterval(-90)) == 90)
        #expect(RetryAfter.parse("Fri, 15 Jan 2027 08:00:00 GMT", now: now.addingTimeInterval(500)) == 0, "past dates clamp to 0")
    }

    @Test func backoffIsExponentialJitteredAndCapped() {
        let policy = RetryPolicy()
        #expect(policy.backoff(forFailureCount: 1, jitter: 0) == 2.5)
        #expect(policy.backoff(forFailureCount: 1, jitter: 1) == 5)
        #expect(policy.backoff(forFailureCount: 2, jitter: 1) == 10)
        #expect(policy.backoff(forFailureCount: 50, jitter: 1) == policy.maxDelay)   // capped
        #expect(policy.backoff(forFailureCount: 50, jitter: 0) >= policy.maxDelay / 2)
        #expect(policy.clamp(retryAfter: 999_999) == policy.maxRetryAfter)
    }
}
