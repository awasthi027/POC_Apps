import Foundation

/// The server's statement of what it durably took responsibility for. See BACKEND_CONTRACT.md.
struct UploadAcknowledgment: Codable, Sendable, Equatable {
    struct Rejection: Codable, Sendable, Equatable {
        var eventID: String
        var reason: String
        var retryable: Bool
        enum CodingKeys: String, CodingKey { case eventID = "event_id", reason, retryable }
    }

    var batchID: String
    var acceptedEventIDs: [String]
    var duplicateEventIDs: [String]
    var rejectedEvents: [Rejection]

    enum CodingKeys: String, CodingKey {
        case batchID = "batch_id", acceptedEventIDs = "accepted_event_ids"
        case duplicateEventIDs = "duplicate_event_ids", rejectedEvents = "rejected_events"
    }

    init(batchID: String, accepted: [String] = [], duplicates: [String] = [], rejected: [Rejection] = []) {
        self.batchID = batchID; acceptedEventIDs = accepted; duplicateEventIDs = duplicates; rejectedEvents = rejected
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        batchID = try c.decode(String.self, forKey: .batchID)
        acceptedEventIDs = try c.decodeIfPresent([String].self, forKey: .acceptedEventIDs) ?? []
        duplicateEventIDs = try c.decodeIfPresent([String].self, forKey: .duplicateEventIDs) ?? []
        rejectedEvents = try c.decodeIfPresent([Rejection].self, forKey: .rejectedEvents) ?? []
    }

    struct Resolution: Equatable {
        /// Accepted or duplicate: the server owns these now. Safe to delete locally.
        var confirmed: Set<String>
        /// Rejected with `retryable == false`. Safe to delete locally; counted as dropped (never "delivered").
        var permanentlyRejected: [String: String]
        /// Every sent ID that is neither confirmed nor permanently rejected: unconfirmed, retryable-rejected,
        /// or contradicted by the server. Must stay in the queue.
        var retain: Set<String>

        var deletable: Set<String> { confirmed.union(permanentlyRejected.keys) }
    }

    /// Reduces the acknowledgment to the sent IDs. Only IDs we actually sent can be acted on; unknown IDs are
    /// ignored. An ID that appears in more than one category is contradictory server output, so it is retained.
    func resolve(sentEventIDs sent: Set<String>) -> Resolution {
        var tally: [String: Int] = [:]
        for id in acceptedEventIDs { tally[id, default: 0] += 1 }
        for id in duplicateEventIDs { tally[id, default: 0] += 1 }
        for r in rejectedEvents { tally[r.eventID, default: 0] += 1 }

        var confirmed = Set<String>(), permanent: [String: String] = [:]
        for id in acceptedEventIDs + duplicateEventIDs where sent.contains(id) && tally[id] == 1 { confirmed.insert(id) }
        for r in rejectedEvents where sent.contains(r.eventID) && tally[r.eventID] == 1 && !r.retryable {
            permanent[r.eventID] = r.reason
        }
        let retain = sent.subtracting(confirmed).subtracting(permanent.keys)
        return Resolution(confirmed: confirmed, permanentlyRejected: permanent, retain: retain)
    }
}
