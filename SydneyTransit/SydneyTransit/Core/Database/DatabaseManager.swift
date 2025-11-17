import Foundation
import GRDB
import Logging

class DatabaseManager {
    static let shared = DatabaseManager()

    private let dbQueue: DatabaseQueue

    private init() {
        do {
            // Get bundle path with better debugging
            guard let path = Bundle.main.path(forResource: "gtfs", ofType: "db") else {
                // Log all resources for debugging
                if let resourcePath = Bundle.main.resourcePath {
                    Logger.database.error("database_not_found_in_bundle", metadata: [
                        "resource_path": "\(resourcePath)",
                        "searched_for": "gtfs.db"
                    ])
                }
                fatalError("gtfs.db not found in bundle")
            }

            // Read-only configuration
            var config = Configuration()
            config.readonly = true
            config.busyMode = .timeout(5.0)

            // Open database
            dbQueue = try DatabaseQueue(path: path, configuration: config)

            Logger.database.info("database_loaded", metadata: ["path": "\(path)"])

            // Validate database with more checks
            try dbQueue.read { db in
                let stopsCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM stops") ?? 0
                let routesCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM routes") ?? 0

                Logger.database.info("database_validated", metadata: [
                    "stops_count": "\(stopsCount)",
                    "routes_count": "\(routesCount)"
                ])

                // Test route decoding
                if let firstRoute = try? Route.fetchOne(db, sql: "SELECT * FROM routes LIMIT 1") {
                    Logger.database.info("route_decode_test_passed", metadata: [
                        "route_id": "\(firstRoute.rid)",
                        "route_name": "\(firstRoute.routeShortName)"
                    ])
                } else {
                    Logger.database.warning("route_decode_test_failed")
                }
            }
        } catch {
            Logger.database.error("database_init_failed", metadata: [
                "error": "\(error.localizedDescription)",
                "error_type": "\(type(of: error))"
            ])
            fatalError("Failed to initialize database: \(error)")
        }
    }

    // Read-only access
    func read<T>(_ block: (Database) throws -> T) throws -> T {
        return try dbQueue.read(block)
    }

    // Get departures from offline GRDB (static schedule)
    func getDepartures(stopId: String, limit: Int = 20) throws -> [Departure] {
        return try read { db in
            // Calculate current time in Sydney timezone
            let sydney = TimeZone(identifier: "Australia/Sydney")!
            let now = Date()
            var cal = Calendar.current
            cal.timeZone = sydney
            let midnight = cal.startOfDay(for: now)
            let timeSecs = Int(now.timeIntervalSince(midnight))

            // Query pattern_stops for next 2 hours
            let sql = """
            SELECT
                ps.departure_offset_secs,
                r.route_short_name,
                t.trip_headsign,
                t.trip_id,
                r.route_type
            FROM pattern_stops ps
            JOIN patterns p ON ps.pid = p.pid
            JOIN trips t ON t.pid = p.pid
            JOIN routes r ON p.rid = r.rid
            WHERE ps.sid = (SELECT sid FROM dict_stop WHERE stop_id = ?)
              AND ps.departure_offset_secs >= ?
              AND ps.departure_offset_secs <= ?
            ORDER BY ps.departure_offset_secs
            LIMIT ?
            """

            let rows = try Row.fetchAll(db, sql: sql, arguments: [stopId, timeSecs, timeSecs + 7200, limit])

            // Map to Departure model
            return rows.map { row in
                let departureTimeSecs: Int = row["departure_offset_secs"]
                return Departure(
                    tripId: row["trip_id"],
                    routeShortName: row["route_short_name"],
                    headsign: row["trip_headsign"],
                    scheduledTimeSecs: departureTimeSecs,
                    realtimeTimeSecs: departureTimeSecs,
                    delayS: 0,
                    realtime: false,
                    platform: nil,
                    wheelchairAccessible: 0,
                    occupancy_status: nil
                )
            }
        }
    }
}
