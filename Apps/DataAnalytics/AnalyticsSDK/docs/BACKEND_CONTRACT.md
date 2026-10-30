# Backend API Contract (Deliverable D)

Specification only; the backend is out of scope. Version: `v1`. Client: `AnalyticsSDK/1.0.0`.

## Endpoint

```
POST /v1/analytics/events
Content-Type: application/json
Accept: application/json
Authorization: Bearer <token>        (omitted if the host supplies no token)
Idempotency-Key: <batch_id>          (hint only; see "Idempotency")
User-Agent: AnalyticsSDK/<sdk_version>
```

### Request

```json
{
  "batch_id": "5b1c…",
  "events": [
    {
      "anonymous_id": "d3f0…",
      "context": { "app_build": "42", "app_version": "1.2.3", "device_model": "iPhone15,2", "locale": "en_US",
                   "network_type": "wifi", "os_name": "iOS", "os_version": "17.0.0", "sdk_version": "1.0.0",
                   "time_zone": "Europe/Berlin" },
      "event_id": "9a7e…",
      "event_name": "product_viewed",
      "properties": { "product_id": "123", "source": "search" },
      "schema_version": 1,
      "session_id": "77c1…",
      "timestamp": "2026-10-29T10:00:00.123Z",
      "user_id": "user-456"
    }
  ],
  "project_id": "example-project",
  "sdk_version": "1.0.0",
  "sent_at": "2026-10-29T10:00:05.000Z"
}
```

* Keys are sorted; each element of `events` is byte-for-byte the JSON stored on the device (identical on every retry).
* `user_id` is omitted for anonymous events. `properties` values are string | integer | double | boolean (flat).
* `sent_at` is the device clock at send time. Servers should estimate skew as `server_receive_time − sent_at` and may adjust event timestamps.
* `schema_version` identifies the *event* schema; servers must accept older versions indefinitely and ignore unknown fields.
* Size limits the client enforces: ≤ 500 events and ≤ `maxBatchBytes` (default 256 KiB) per request; ≤ 16 KiB per event. The server should accept at least these and answer 413 above its own limit.
* SDK-generated event names start with `$`: `$session_start`, `$session_end` (`reason`: timeout | interrupted | explicit | identity_changed; `session_duration_ms`), `$identify` (user traits as properties), `$screen_view` (`screen_name`).

### Success response — `200 OK`

```json
{
  "batch_id": "5b1c…",
  "accepted_event_ids":  ["e1", "e4"],
  "duplicate_event_ids": ["e2"],
  "rejected_events": [
    { "event_id": "e3", "reason": "invalid_schema", "retryable": false },
    { "event_id": "e5", "reason": "temporarily_unavailable", "retryable": true }
  ]
}
```

Missing arrays are treated as empty. `batch_id` **must** echo the request.

## Semantics

1. **Acknowledge only after durable acceptance.** The server may list an ID in `accepted_event_ids` or `duplicate_event_ids` only after the event is durably stored (or durably enqueued to a log with replication) *and* its `(project_id, event_id)` key is durably recorded. A server that cannot do this must not return 200 for those events.
2. **HTTP 2xx is not sufficient to delete.** The SDK deletes only events whose IDs appear in a valid 200 acknowledgment. A 200 with a missing/invalid body or a mismatched `batch_id`, any 201–299 (including **202 Accepted** and **204 No Content**), is a *malformed acknowledgment*: nothing is deleted and the batch is retried.
3. **Partial acceptance.** Each event is acknowledged individually. The SDK deletes accepted + duplicate + non-retryable-rejected IDs, and keeps every other sent ID (unlisted, `retryable: true`, or listed in more than one category) for retry with backoff.
4. **Duplicates.** An event already stored under the same key is reported in `duplicate_event_ids`; the client treats this exactly like `accepted`. This is what makes the lost-response scenario safe.
5. **De-duplication scope.** Key = `(project_id, event_id)`. `event_id` is a client-generated UUID, stable across retries and across app restarts. Retention of dedupe keys must be at least the client's maximum retry horizon (default retention 7 days) plus clock-skew slack; recommended ≥ 30 days.
6. **Malformed responses.** Treated as unconfirmed (see 2). Repeated malformed responses consume the per-event attempt budget (default 8) and then the events are dropped and counted.
7. **Rate limits and retry hints.** `429` and `503` may carry `Retry-After` (delta-seconds or HTTP-date). The client honours it, clamped to ≤ 1 h; an invalid value is ignored and exponential backoff applies. A 429 does not consume the events' attempt budget. Backoff is global (no parallel per-event retries).
8. **Rejected events.** `retryable: false` → client drops the event (counted as `permanentlyRejected`; not retried, not quarantined). `retryable: true` → retried like an unacknowledged event. Suggested `reason` codes: `invalid_schema`, `unknown_event`, `too_large`, `pii_policy`, `temporarily_unavailable`.
9. **Authentication failures.**

| Status | Meaning | Client behaviour |
|---|---|---|
| 401 | Token missing/expired | One credential refresh (`CredentialProvider.refreshToken`) and one resend; if still 401 → pause uploads 15 min (events retained, attempts not consumed) until `credentialsDidChange()` |
| 403, other 3xx/4xx not listed | Project disabled, wrong endpoint, key lacks scope | Pause 1 h; events retained; surfaced as `FlushStatus.authenticationRequired` |
| 400, 422 | Batch not acceptable as sent | Bisect: halve batch until the offending event is alone, then drop it (counted) |
| 413 | Body too large | Same bisection as 400/422 |
| 408, 5xx | Transient | Retry with exponential backoff + jitter (5 s base, ×2, 15 min cap), counts against attempt budget |
| 429 | Rate limited | `Retry-After` or backoff, no attempt consumed |

## Idempotency and delivery guarantees

* `event_id` is the idempotency key. `batch_id` is **not**: a batch that is re-leased after a restart gets a new `batch_id` but the same `event_id`s, and batches may be re-composed differently. `Idempotency-Key: <batch_id>` may be used to short-circuit same-batch replays within one process lifetime, but correctness must not depend on it.
* The system provides **at-least-once delivery attempts from the SDK, plus idempotent server ingestion keyed by `(project_id, event_id)`**. That yields *effectively-once storage* if (and only if) the server's "check key + persist event + record key" is atomic and durable. It is **not** exactly-once network delivery.
* Downstream consumers (warehouse, billing, notifications) must be idempotent on `event_id`, or consume only from the de-duplicated store. If duplicate business effects are unacceptable, they must not be triggered from raw ingest.
* Events can arrive out of order and late (offline queues up to 7 days). Order by `timestamp` (skew-corrected), not arrival.
* After consent revocation an in-flight batch cannot be recalled; the server should provide a deletion API keyed by `anonymous_id`/`user_id` for erasure requests (outside the SDK).
* Authentication: bearer token per app/project, short-lived if possible; the SDK never logs it and the host may keep it in Keychain (`KeychainCredentialProvider`).
