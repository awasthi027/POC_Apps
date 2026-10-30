import Foundation

/// One upload attempt. `batchID` is chosen when the batch is leased; it is reused if the *same lease* is
/// retried in-process, but a re-leased batch after a restart gets a new `batchID` — idempotency is therefore
/// keyed on `event_id`, never on `batch_id` (see BACKEND_CONTRACT.md).
struct UploadRequest: Sendable, Equatable {
    var batchID: String
    var projectID: String
    var sdkVersion: String
    var sentAt: Date
    var events: [LeasedEvent]

    /// Upper bound of the bytes the envelope adds around the comma-joined event payloads. Used by the store
    /// to enforce `maxBatchBytes` exactly, without re-encoding anything.
    static func envelopeOverhead(projectID: String, sdkVersion: String = AnalyticsSDKInfo.version) -> Int {
        // Fixed keys/punctuation + 36-char UUID + 24-char timestamp + generous slack; JSON escaping can expand a
        // string up to 6x (\uXXXX).
        256 + 6 * (projectID.utf8.count + sdkVersion.utf8.count)
    }

    /// Body bytes. Event payloads are spliced in verbatim, so a retried event is byte-identical to its first send.
    func encodedBody() throws -> Data {
        let encoder = WireFormat.makeEncoder()
        func json(_ s: String) throws -> Data { try encoder.encode(s) }
        var body = Data()
        body.append(Data(#"{"batch_id":"#.utf8)); body.append(try json(batchID))
        body.append(Data(#","events":["#.utf8))
        for (i, event) in events.enumerated() {
            if i > 0 { body.append(0x2C) }
            body.append(event.payload)
        }
        body.append(Data(#"],"project_id":"#.utf8)); body.append(try json(projectID))
        body.append(Data(#","sdk_version":"#.utf8)); body.append(try json(sdkVersion))
        body.append(Data(#","sent_at":"#.utf8)); body.append(try json(WireFormat.timestampString(sentAt)))
        body.append(0x7D)
        return body
    }
}
