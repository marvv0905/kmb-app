import Foundation
import SQLite3

final class AppDatabase {
    private var db: OpaquePointer?
    private let databaseURL: URL
    private let queue = DispatchQueue(label: "com.kmbapp.database", qos: .userInitiated)

    init() throws {
        databaseURL = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("kmb_app.sqlite")

        try openAndMigrate()
    }

    private func openAndMigrate() throws {
        try? FileManager.default.removeItem(at: databaseURL.appendingPathExtension("wal"))
        try? FileManager.default.removeItem(at: databaseURL.appendingPathExtension("shm"))

        var dbRef: OpaquePointer?
        if sqlite3_open(databaseURL.path, &dbRef) != SQLITE_OK {
            throw DatabaseError.openFailed(Self.msg(dbRef))
        }
        db = dbRef

        try execute(sql: "PRAGMA journal_mode = DELETE")
        try execute(sql: "PRAGMA foreign_keys = ON")

        do {
            try runMigrations()
        } catch {
            close()
            try? FileManager.default.removeItem(at: databaseURL)
            try openAndMigrate()
        }
    }

    deinit { close() }

    private func close() {
        guard let db = db else { return }
        sqlite3_close(db)
        self.db = nil
    }

    func read<T>(_ block: @escaping (OpaquePointer) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            queue.async { [weak self] in
                guard let self, let db = self.db else { cont.resume(throwing: DatabaseError.databaseClosed); return }
                do { cont.resume(returning: try block(db)) }
                catch { cont.resume(throwing: error) }
            }
        }
    }

    func write<T>(_ block: @escaping (OpaquePointer) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            queue.async { [weak self] in
                guard let self, let db = self.db else { cont.resume(throwing: DatabaseError.databaseClosed); return }
                do {
                    try Self.exec(db: db, sql: "BEGIN IMMEDIATE")
                    let result = try block(db)
                    try Self.exec(db: db, sql: "COMMIT")
                    cont.resume(returning: result)
                } catch {
                    try? Self.exec(db: db, sql: "ROLLBACK")
                    cont.resume(throwing: error)
                }
            }
        }
    }

    private func execute(sql: String) throws {
        guard let db = db else { throw DatabaseError.databaseClosed }
        try Self.exec(db: db, sql: sql)
    }

    private static func exec(db: OpaquePointer, sql: String) throws {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            throw DatabaseError.sqlError(msg(db))
        }
    }

    private func runMigrations() throws {
        guard let db = db else { throw DatabaseError.databaseClosed }

        try Self.exec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS routes (
                operator TEXT NOT NULL, route_code TEXT NOT NULL, bound TEXT NOT NULL,
                service_type TEXT, region TEXT,
                orig_en TEXT, orig_tc TEXT, orig_sc TEXT,
                dest_en TEXT, dest_tc TEXT, dest_sc TEXT,
                data_timestamp TEXT,
                PRIMARY KEY (operator, route_code, bound, service_type, region)
            );
        """)
        try Self.exec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS stops (
                operator TEXT NOT NULL, stop_id TEXT NOT NULL,
                name_en TEXT, name_tc TEXT, name_sc TEXT,
                lat REAL NOT NULL, long REAL NOT NULL,
                region TEXT, data_timestamp TEXT,
                PRIMARY KEY (operator, stop_id)
            );
        """)
        try Self.exec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS route_stops (
                operator TEXT NOT NULL, route_code TEXT NOT NULL, bound TEXT NOT NULL,
                service_type TEXT, seq INTEGER NOT NULL, stop_id TEXT NOT NULL,
                PRIMARY KEY (operator, route_code, bound, service_type, seq)
            );
        """)
        try Self.exec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS sync_meta (key TEXT PRIMARY KEY, value TEXT);
        """)
    }

    private static func msg(_ db: OpaquePointer?) -> String {
        sqlite3_errmsg(db).map(String.init(cString:)) ?? "unknown"
    }

    static let shared = try! AppDatabase()
}

enum DatabaseError: LocalizedError {
    case openFailed(String), databaseClosed, sqlError(String)
    var errorDescription: String? {
        switch self {
        case .openFailed(let m): return "DB open failed: \(m)"
        case .databaseClosed: return "Database closed"
        case .sqlError(let m): return "SQL error: \(m)"
        }
    }
}
