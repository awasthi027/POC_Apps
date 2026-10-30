import Foundation

struct DatabaseMigration {
    let version: Int
    let statements: [String]
}

/// Forward-only migrations keyed by `PRAGMA user_version`. Each migration runs in its own transaction, so a
/// crash mid-migration leaves the previous version intact. A database *newer* than this build (app downgrade)
/// is refused rather than guessed at.
struct DatabaseMigrator {
    var migrations: [DatabaseMigration]

    static let standard = DatabaseMigrator(migrations: [
        DatabaseMigration(version: 1, statements: [
            """
            CREATE TABLE events (
                seq              INTEGER PRIMARY KEY AUTOINCREMENT,   -- ingestion order
                event_id         TEXT    NOT NULL UNIQUE,             -- stable across retries; dedupe key
                created_at       REAL    NOT NULL,                    -- event timestamp (unix seconds)
                payload          BLOB    NOT NULL,                    -- exact wire JSON of the event
                payload_bytes    INTEGER NOT NULL,
                attempts         INTEGER NOT NULL DEFAULT 0,          -- counted attempts (see RetryPolicy)
                next_attempt_at  REAL    NOT NULL DEFAULT 0,          -- backoff gate
                lease_id         TEXT,                                -- batch currently owning the row
                lease_expires_at REAL
            )
            """,
            // Eligibility scan: unleased rows ordered by seq with next_attempt_at gate.
            "CREATE INDEX idx_events_eligible ON events (lease_id, next_attempt_at, seq)",
            // Resolve-by-batch lookup.
            "CREATE INDEX idx_events_lease ON events (lease_id) WHERE lease_id IS NOT NULL",
            // Retention sweep.
            "CREATE INDEX idx_events_created ON events (created_at)",
            "CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)"
        ])
    ])

    var latestVersion: Int { migrations.map(\.version).max() ?? 0 }

    func migrate(_ db: SQLiteDatabase) throws {
        let current = try db.query("PRAGMA user_version") { Int($0.int(0)) }.first ?? 0
        guard current <= latestVersion else {
            throw AnalyticsError.incompatibleDatabase(found: current, supported: latestVersion)
        }
        for migration in migrations.sorted(by: { $0.version < $1.version }) where migration.version > current {
            try db.transaction {
                for statement in migration.statements { try db.execute(statement) }
                try db.execute("PRAGMA user_version = \(migration.version)")
            }
        }
    }
}
