import Foundation
import SQLite3

final class StopRepository {
    private let database: AppDatabase

    init(database: AppDatabase) { self.database = database }

    func upsertStops(_ stops: [BusStop]) async throws {
        try await database.write { db in
            let sql = "INSERT OR REPLACE INTO stops (operator, stop_id, name_en, name_tc, name_sc, lat, long, region, data_timestamp) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            for s in stops {
                sqlite3_bind_text(stmt, 1, s.operatorType.rawValue, -1, nil)
                sqlite3_bind_text(stmt, 2, s.rawStopId, -1, nil)
                sqlite3_bind_text(stmt, 3, s.nameEn, -1, nil)
                sqlite3_bind_text(stmt, 4, s.nameTc, -1, nil)
                sqlite3_bind_text(stmt, 5, s.nameSc, -1, nil)
                sqlite3_bind_double(stmt, 6, s.latitude)
                sqlite3_bind_double(stmt, 7, s.longitude)
                if let r = s.region { sqlite3_bind_text(stmt, 8, r, -1, nil) } else { sqlite3_bind_null(stmt, 8) }
                if let t = s.dataTimestamp { sqlite3_bind_text(stmt, 9, t, -1, nil) } else { sqlite3_bind_null(stmt, 9) }
                sqlite3_step(stmt)
                sqlite3_reset(stmt)
            }
        }
    }

    func stopsForOperator(_ op: BusOperator) async throws -> [BusStop] {
        try await database.read { db in
            var stops = [BusStop]()
            let sql = "SELECT operator, stop_id, name_en, name_tc, name_sc, lat, long, region, data_timestamp FROM stops WHERE operator = ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return stops }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, op.rawValue, -1, nil)
            while sqlite3_step(stmt) == SQLITE_ROW {
                stops.append(Self.rowToStop(stmt))
            }
            return stops
        }
    }

    private static func rowToStop(_ s: OpaquePointer?) -> BusStop {
        let c = { (i: Int32) -> String? in sqlite3_column_text(s, i).map(String.init(cString:)) }
        return BusStop(
            operatorType: BusOperator(rawValue: c(0) ?? "kmb") ?? .kmb,
            rawStopId: c(1) ?? "",
            nameEn: c(2) ?? "", nameTc: c(3) ?? "", nameSc: c(4) ?? "",
            latitude: sqlite3_column_double(s, 5),
            longitude: sqlite3_column_double(s, 6),
            region: c(7), dataTimestamp: c(8)
        )
    }
}
