import Foundation
import SQLite3

/// Thin wrapper over the system SQLite3 C API. It is the only third-party-free "library" the store needs;
/// everything above it talks to the `EventStore` protocol, so swapping in GRDB/SQLite.swift later touches
/// only `SQLiteEventStore`. Not thread-safe: confined to the owning actor.
struct SQLiteError: Error {
    let code: Int32
    let message: String

    var isCorruption: Bool { code == SQLITE_CORRUPT || code == SQLITE_NOTADB }

    var analyticsError: AnalyticsError {
        switch code {
        case SQLITE_FULL: return .diskFull
        case SQLITE_CORRUPT, SQLITE_NOTADB: return .storageCorrupted
        default: return .storageFailure(code: code)
        }
    }
}

enum SQLiteValue {
    case int(Int64)
    case double(Double)
    case text(String)
    case blob(Data)
    case null
}

struct SQLiteRow {
    fileprivate let stmt: OpaquePointer
    func int(_ i: Int32) -> Int64 { sqlite3_column_int64(stmt, i) }
    func double(_ i: Int32) -> Double { sqlite3_column_double(stmt, i) }
    func isNull(_ i: Int32) -> Bool { sqlite3_column_type(stmt, i) == SQLITE_NULL }
    func text(_ i: Int32) -> String { sqlite3_column_text(stmt, i).map { String(cString: $0) } ?? "" }
    func blob(_ i: Int32) -> Data {
        guard let p = sqlite3_column_blob(stmt, i) else { return Data() }
        return Data(bytes: p, count: Int(sqlite3_column_bytes(stmt, i)))
    }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class SQLiteDatabase {
    private var handle: OpaquePointer?

    init(path: String) throws {
        var h: OpaquePointer?
        let rc = sqlite3_open_v2(path, &h, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil)
        guard rc == SQLITE_OK, let h else {
            let message = h.map { String(cString: sqlite3_errmsg($0)) } ?? "open failed"
            if let h { sqlite3_close(h) }
            throw SQLiteError(code: rc, message: message)
        }
        handle = h
        sqlite3_busy_timeout(h, 2_000)
    }

    deinit { close() }

    func close() {
        if let h = handle { sqlite3_close_v2(h); handle = nil }
    }

    private func db() throws -> OpaquePointer {
        guard let handle else { throw SQLiteError(code: SQLITE_MISUSE, message: "database closed") }
        return handle
    }

    private func error(_ code: Int32) -> SQLiteError {
        SQLiteError(code: code & 0xFF, message: handle.map { String(cString: sqlite3_errmsg($0)) } ?? "closed")
    }

    func execute(_ sql: String) throws {
        let h = try db()
        let rc = sqlite3_exec(h, sql, nil, nil, nil)
        guard rc == SQLITE_OK else { throw error(rc) }
    }

    @discardableResult
    func run(_ sql: String, _ binds: [SQLiteValue] = []) throws -> Int {
        try withStatement(sql, binds) { stmt in
            let rc = sqlite3_step(stmt)
            guard rc == SQLITE_DONE || rc == SQLITE_ROW else { throw error(rc) }
        }
        return Int(sqlite3_changes(try db()))
    }

    func query<T>(_ sql: String, _ binds: [SQLiteValue] = [], _ map: (SQLiteRow) throws -> T) throws -> [T] {
        var out: [T] = []
        try withStatement(sql, binds) { stmt in
            while true {
                let rc = sqlite3_step(stmt)
                if rc == SQLITE_ROW { out.append(try map(SQLiteRow(stmt: stmt))) }
                else if rc == SQLITE_DONE { break }
                else { throw error(rc) }
            }
        }
        return out
    }

    /// `BEGIN IMMEDIATE` takes the write lock up front so a transaction never fails midway on lock upgrade.
    /// Any thrown error (including a failing COMMIT, e.g. SQLITE_FULL) rolls back: all-or-nothing.
    func transaction<T>(_ body: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE")
        do {
            let result = try body()
            try execute("COMMIT")
            return result
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func withStatement(_ sql: String, _ binds: [SQLiteValue], _ body: (OpaquePointer) throws -> Void) throws {
        let h = try db()
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(h, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let stmt else { throw error(rc) }
        defer { sqlite3_finalize(stmt) }
        for (i, value) in binds.enumerated() {
            let idx = Int32(i + 1)
            let brc: Int32
            switch value {
            case .int(let v): brc = sqlite3_bind_int64(stmt, idx, v)
            case .double(let v): brc = sqlite3_bind_double(stmt, idx, v)
            case .text(let v): brc = sqlite3_bind_text(stmt, idx, v, -1, sqliteTransient)
            case .blob(let v): brc = v.withUnsafeBytes { sqlite3_bind_blob(stmt, idx, $0.baseAddress, Int32(v.count), sqliteTransient) }
            case .null: brc = sqlite3_bind_null(stmt, idx)
            }
            guard brc == SQLITE_OK else { throw error(brc) }
        }
        try body(stmt)
    }
}
