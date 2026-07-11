import Foundation
import SQLite3

final class SyncMetaRepository {
    private let database: AppDatabase

    init(database: AppDatabase) { self.database = database }

    func lastSyncTimestamp(for key: String) async throws -> Date? {
        try await database.read { db in
            let sql = "SELECT value FROM sync_meta WHERE key = ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, key, -1, nil)
            guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
            guard let iso = sqlite3_column_text(stmt, 0).map(String.init(cString:)) else { return nil }
            return ISO8601DateFormatter().date(from: iso)
        }
    }

    func setSyncTimestamp(_ date: Date, for key: String) async throws {
        try await database.write { db in
            let sql = "INSERT OR REPLACE INTO sync_meta (key, value) VALUES (?, ?)"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            let iso = ISO8601DateFormatter().string(from: date)
            sqlite3_bind_text(stmt, 1, key, -1, nil)
            sqlite3_bind_text(stmt, 2, iso, -1, nil)
            sqlite3_step(stmt)
        }
    }
}
