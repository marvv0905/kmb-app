import Foundation
import SQLite3

final class RouteRepository {
    private let database: AppDatabase

    init(database: AppDatabase) { self.database = database }

    func upsertRoutes(_ routes: [BusRoute]) async throws {
        try await database.write { db in
            let sql = "INSERT OR REPLACE INTO routes (operator, route_code, bound, service_type, region, orig_en, orig_tc, orig_sc, dest_en, dest_tc, dest_sc, data_timestamp) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            for r in routes {
                let b: (Int32, String) -> Void = { sqlite3_bind_text(stmt, $0, $1, -1, nil) }
                let n: (Int32) -> Void = { sqlite3_bind_null(stmt, $0) }
                b(1, r.operatorType.rawValue); b(2, r.routeCode); b(3, r.bound)
                if let s = r.serviceType { b(4, s) } else { n(4) }
                if let rg = r.region { b(5, rg) } else { n(5) }
                b(6, r.originEn); b(7, r.originTc); b(8, r.originSc)
                b(9, r.destEn); b(10, r.destTc); b(11, r.destSc)
                if let t = r.dataTimestamp { b(12, t) } else { n(12) }
                sqlite3_step(stmt)
                sqlite3_reset(stmt)
            }
        }
    }

    func routesForOperator(_ op: BusOperator) async throws -> [BusRoute] {
        try await database.read { db in
            var routes = [BusRoute]()
            let sql = "SELECT operator, route_code, bound, service_type, region, orig_en, orig_tc, orig_sc, dest_en, dest_tc, dest_sc, data_timestamp FROM routes WHERE operator = ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return routes }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, op.rawValue, -1, nil)
            while sqlite3_step(stmt) == SQLITE_ROW { routes.append(Self.rowToRoute(stmt)) }
            return routes
        }
    }

    func routesAtStop(operator op: BusOperator, stopId: String) async throws -> [BusRoute] {
        try await database.read { db in
            var routes = [BusRoute]()
            let sql = """
                SELECT DISTINCT r.operator, r.route_code, r.bound, r.service_type, r.region,
                    r.orig_en, r.orig_tc, r.orig_sc, r.dest_en, r.dest_tc, r.dest_sc, r.data_timestamp
                FROM routes r JOIN route_stops rs ON r.operator = rs.operator AND r.route_code = rs.route_code
                    AND r.bound = rs.bound AND (r.service_type = rs.service_type OR (r.service_type IS NULL AND rs.service_type IS NULL))
                WHERE rs.operator = ? AND rs.stop_id = ?
                """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return routes }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, op.rawValue, -1, nil)
            sqlite3_bind_text(stmt, 2, stopId, -1, nil)
            while sqlite3_step(stmt) == SQLITE_ROW { routes.append(Self.rowToRoute(stmt)) }
            return routes
        }
    }

    func upsertAllRouteStops(operator op: BusOperator, pairs: [KMBRouteStopData]) async throws {
        try await database.write { db in
            let sql = "INSERT OR REPLACE INTO route_stops (operator, route_code, bound, service_type, seq, stop_id) VALUES (?, ?, ?, ?, ?, ?)"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            for p in pairs {
                sqlite3_bind_text(stmt, 1, op.rawValue, -1, nil)
                sqlite3_bind_text(stmt, 2, p.route, -1, nil)
                sqlite3_bind_text(stmt, 3, p.bound, -1, nil)
                if let s = p.serviceType { sqlite3_bind_text(stmt, 4, s, -1, nil) } else { sqlite3_bind_null(stmt, 4) }
                sqlite3_bind_int(stmt, 5, Int32(p.seq) ?? 0)
                sqlite3_bind_text(stmt, 6, p.stop, -1, nil)
                sqlite3_step(stmt)
                sqlite3_reset(stmt)
            }
        }
    }

    private static var debugRowCount = 0

    private static func rowToRoute(_ s: OpaquePointer?) -> BusRoute {
        let c = { (i: Int32) -> String? in sqlite3_column_text(s, i).map(String.init(cString:)) }
        if debugRowCount < 5 {
            print("[DB row \(debugRowCount)] op=\(c(0) ?? "nil") code=\(c(1) ?? "nil") bound=\(c(2) ?? "nil")")
            debugRowCount += 1
        }
        return BusRoute(
            operatorType: BusOperator(rawValue: c(0) ?? "kmb") ?? .kmb,
            routeCode: c(1) ?? "", bound: c(2) ?? "",
            serviceType: c(3), region: c(4),
            originEn: c(5) ?? "", originTc: c(6) ?? "", originSc: c(7) ?? "",
            destEn: c(8) ?? "", destTc: c(9) ?? "", destSc: c(10) ?? "",
            dataTimestamp: c(11)
        )
    }
}
