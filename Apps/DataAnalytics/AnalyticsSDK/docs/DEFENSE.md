# Cross-questions and answers (Deliverable F)

Format: **Chosen** (what the code does) · *Alternative* (and when it would win). Test names point at executable evidence.

**1. Why an SDK instead of calling analytics directly from the app?**
**Chosen:** one tested module owns durability, batching, retry, consent and privacy so every feature team gets them for free and the policy is auditable in one place. *Alternative:* direct calls are fine for a single screen/prototype or when a vendor SDK already provides all of this; they stop being fine once you need offline durability and consent enforcement consistently.

**2. Why a facade?**
**Chosen:** `AnalyticsSDK` is the only public entry point, ~15 methods, no logic; internals can be re-wired (store, transport, scheduler) without breaking callers. *Alternative:* expose components for power users — rejected because it freezes internal types as API.

**3. Why not make every component a singleton?**
**Chosen:** constructor injection; one `AnalyticsSDK` instance per project, each with its own database file, clock, transport and connectivity. Singletons hide dependencies, make tests share state, and block multi-project use. *Alternative:* a host-owned `static let shared` around the facade is fine; the SDK just does not force it or keep global mutable state.

**4. Why SQLite over SwiftData?**
**Chosen:** SQLite (system lib + small wrapper behind `EventStore`): iOS 15 floor, explicit transactions, partial indexes, `INSERT OR IGNORE`, WAL, bounded `LIMIT` scans, exact control over schema/migrations and file protection. SwiftData is iOS 17+, object-graph oriented and gives less control over locking and when data is flushed. Core Data works on older iOS but adds contexts/merge policies for what is a simple queue. *Alternative:* if the app is iOS 17+ only and already uses SwiftData, it is viable; GRDB is the better swap if the team accepts a dependency (it would replace `SQLiteDatabase`, nothing else).

**5. Why an actor instead of a serial dispatch queue?**
**Chosen:** actors integrate with `async/await` (no completion-handler bridging), the compiler checks isolation, and a suspended caller does not block a thread. We still use `NSLock` for tiny synchronous state that must be readable without `await`. *Alternative:* a serial queue is better when you need synchronous reads, must support pre-concurrency OS versions, or want explicit QoS control of a long-running writer.

**6. Does an actor prevent all race conditions?**
No. It serialises access to its own state, but is *re-entrant*: at every `await` another call can run. A workflow like "select batch → upload → delete" spans awaits, so the actor alone does not make it atomic. Here atomicity comes from (a) SQLite transactions that contain no `await` (`SQLiteEventStore` methods are synchronous inside the actor), (b) DB leases so no two callers own an event, (c) generation counters for coalescing triggers. `testConcurrentLeasesNeverOverlap`, `testConcurrentFlushesNeverOverlapUploadsAndEventsAreSentOnce`.

**7. What happens if the app crashes immediately after `track()`?**
If `track` returned, the event's transaction committed (WAL) → it is on disk and is uploaded next launch (`testRestartRecoversPendingEventsAndUploadsWithOriginalIDs`). If the crash happened before it returned, the event may or may not be stored; the caller never saw success, so no promise was broken. With `enqueue`, "accepted" means buffered in memory only: a crash loses up to one group (≤ `ingressCapacity`). *Alternative:* `track` for events that matter (purchase), `enqueue` for high-frequency telemetry.

**8. The server processed an event but the acknowledgment was lost?**
The event stays queued, with the same `event_id` and identical bytes. On retry the server answers `duplicate_event_ids`; the SDK treats that as confirmed and deletes it (`testLostAcknowledgmentThenRetryReusesIDsAndDuplicateAckClearsQueue`, `testKillDuringUploadRecoversAbandonedLeaseOnNextLaunch`).

**9. How do you prevent duplicate analytics events?**
Two layers: the client keeps IDs stable (generated once in `EventProcessor`, persisted in payload and a `UNIQUE` column, so a re-insert is idempotent) and the server de-duplicates on `(project_id, event_id)`. The client cannot *prevent* duplicate delivery, only make it harmless.

**10. Why isn't exactly-once delivery guaranteed?**
Because of the Two Generals problem: after sending, the client cannot distinguish "server never got it" from "server got it, reply lost". Retrying risks duplicates; not retrying risks loss. We choose at-least-once + idempotent receiver, which yields effectively-once *storage*, not exactly-once *delivery*, and only if the server's check-and-store is atomic. Downstream side effects must also be idempotent.

**11. What if the server accepts only half a batch?**
Per-event acknowledgment: accepted/duplicate/non-retryable-rejected are deleted in one transaction; the rest are released with backoff (`testPartialAckDeletesOnlyConfirmedEvents…`, `testAcknowledgmentResolutionRules`). *Alternative:* all-or-nothing batches are simpler for the server but force re-sending already-accepted events and make one poison event block the batch.

**12. Why not delete after any 2xx?**
A 2xx proves the HTTP exchange succeeded, not that *these* events are durable: 202 means "queued", proxies/captive portals return 200 with HTML, bugs return `{}`. Deleting on that would silently lose data. We delete only IDs listed in a valid 200 ack that echoes `batch_id` (`testMalformedOrNonDurableSuccessNeverDeletes`).

**13. What happens when the database is full?**
Two limits, both enforced inside the insert transaction: `maxQueuedEvents` and `maxQueuedBytes`. `.dropOldest` (default) evicts the oldest *unleased* events, never an in-flight upload, and counts them (`evictedForSpace`); `.rejectNew` makes `track` throw `storageFull`. If *every* row is leased the new event is refused rather than evicting in-flight data. Device disk full (`SQLITE_FULL`) rolls back and throws `diskFull`. Nothing is dropped silently (`testStorageFullRejectNew…`, `testStorageFullDropOldest…`, `testDropOldestEvictsUnleasedButNeverLeased`). *Alternative:* drop-newest preserves history instead of recency; choose it if old events matter more.

**14. 10,000 events arriving rapidly?**
`enqueue` appends to a bounded buffer (default 2,000) under a lock; **one** drain task writes ≤200 events per transaction; beyond capacity `enqueue` returns `.rejected(.backpressure)` and it is counted. No per-event task, no unbounded queue, fsync cost amortised (`testTenThousandRapidEnqueuesAreBoundedAndAccountedFor`: accepted + backpressured == 10,000, stored == accepted + 1). `track` callers just wait their turn.

**15. Two flush requests at once?**
Each bumps a generation counter and waits for a pass that *starts after* it. One worker runs passes until it has caught up; both callers resume; the second pass finds nothing eligible. Never two uploads of the same events (`testConcurrentFlushesNeverOverlapUploads…`: 5 flushes, max in-flight requests = 1).

**16. App killed during upload?**
The batch was leased, not deleted. Next launch `recoverAllLeases()` returns those rows to the queue (attempt count kept, so a crashing poison event is eventually dropped). They re-upload with the same IDs; if the server had already stored them it replies `duplicate`. In-process, an expired lease is recovered each pass (`testKillDuringUpload…`, `testLeasedEventsAreInvisibleUntilResolvedOrRecovered`).

**17. How do you avoid blocking the main thread?**
Public async methods are nonisolated (they run on the cooperative pool), SQLite runs inside an actor, networking is `URLSession` async. The only thing a caller does synchronously is `enqueue`'s short lock + JSON encode of one small event (microseconds). Nothing waits on I/O synchronously; no `DispatchSemaphore`, no `.sync`.

**18. Server returns 429?**
Honour `Retry-After` (delta or date, clamped to ≤1 h; invalid → normal backoff), apply it globally (not per event), and refund the attempt so rate limiting never causes event loss (`testRateLimitHonoursRetryAfter…`).

**19. Authentication fails?**
401: one credential refresh and one resend; still 401 → pause 15 min, keep events, don't burn attempts, report `.authenticationRequired`; `credentialsDidChange()` resumes immediately. 403/unknown 4xx: pause 1 h (config error). No retry storm, no data loss until retention (`testAuthFailurePausesUploadsUntilCredentialsChange`).

**20. How are sessions recovered after a crash?**
Session `{id, startedAt, lastActivityAt}` is written in the same transaction as the events. On launch: gap ≤ timeout → resume same ID; otherwise emit `$session_end(reason: interrupted)` stamped at the last known activity and start a new one on the next event (`testSessionResumesAfterQuickRestart…`). Limitation: `lastActivityAt` can lag by the events lost in a crash window.

**21. User revokes consent?**
New events stop immediately (flag flipped inside the ingress lock, so nothing slips in); the buffer is discarded; "denied" is persisted *before* deletion; the in-flight commit is awaited; all queued rows, identity and session are deleted; a crash mid-way is completed at next launch. Uploads are gated on consent regardless of policy. Not possible: recalling a request already on the wire. *Alternative:* `.retainQueuedEvents` keeps data for re-grant but is legally riskier (`testRevocationDeletesQueuedEvents…`, `testRetainPolicy…`).

**22. How do you prevent unbounded retries?**
Per-event counted-attempt budget (default 8) after which the event is dropped and counted; exponential backoff capped at 15 min with jitter; global backoff so a failing server isn't hammered; retention (7 d) and queue caps; offline/429/auth failures are *not* counted because the event isn't at fault, but are gated by connectivity, Retry-After and pauses instead; permanently rejected events are deleted; poison batches are bisected to a single event and dropped (`testServerErrorsBackOff…`, `testPoisonEventIsIsolatedByBisection…`).

**23. Multiple projects/tenants?**
One `AnalyticsSDK` instance per `projectID`: separate DB file (`…/AnalyticsSDK/<project>/events.sqlite`), credentials, consent, identity and queue; no shared mutable state, so one tenant's backlog or auth failure cannot affect another. The server dedupes on `(project_id, event_id)`. *Alternative:* one shared queue with a `project_id` column saves files/connectivity monitors but couples failure domains and complicates per-tenant consent deletion.

**24. Schema evolution?**
Wire: `schema_version` in every event; stored payloads are the wire JSON, so old queued events keep their old shape and the server must accept old versions; add fields as optional. DB: `user_version` migrations, each transactional; downgrades refused (`testMigrationsRun…`). Properties are a flat typed map so adding event types needs no client schema change. Breaking wire changes: new endpoint version + drain the old queue first.

**25. What changes at 1,000 events/second?**
Today's design handles it in the write path (group commit) but not the upload path: one in-flight 50-event batch every ~RTT gives ~hundreds/s at best. Changes: larger batches (500) + gzip/Protobuf; raise commit group size and use prepared statement reuse; consider `synchronous=NORMAL` with larger WAL checkpoints; more than one upload worker (leases already make that correct; ordering is already best effort); sampling/aggregation on device because 1,000 eps on a phone is almost always a design smell; background URLSession or HTTP/2 multiplexing; a ring-buffer log file instead of SQLite if per-row indexing becomes the bottleneck. Verify with the queue-age and ack-latency metrics before changing anything.

**26. Which metrics reveal an unhealthy SDK?**
`oldestEventAge` and `pendingEvents` trending up; `uploadSuccessRate` down; high `retriesScheduled / eventsAcknowledged`; any growth in `maxAttempts`, `permanentlyRejected`, `storageFull`, `backpressure`, `persistenceFailed` drops; `databaseRebuilds > 0`; creation→ack latency p95; `uploadsPausedUntil` set (auth/config); track latency p99; DB disk bytes vs payload bytes. Alert on rates per app version, not absolute counts.

**27. Biggest limitations?**
(1) Not exactly-once — depends on a correct idempotent server. (2) `enqueue` is not durable and can lose the in-memory buffer on a crash. (3) `synchronous=NORMAL` can lose the last commits on power loss. (4) Single worker caps throughput; retries reorder delivery. (5) Wall-clock timestamps from the device (skew; server must correct). (6) PII detection is heuristic. (7) A corrupt DB loses the queue (reported). (8) No quarantine/gzip/BGTask/background URLSession/extension-sharing yet. (9) Foreground-only uploads: events from an app that is never reopened stay on the device until the retention window expires. (10) Several paths are untested on device (see DESIGN.md §G).
