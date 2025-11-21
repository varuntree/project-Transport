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
                    Logger.database.error(
                        "database_not_found_in_bundle",
                        metadata: .from([
                            "resource_path": resourcePath,
                            "searched_for": "gtfs.db"
                        ])
                    )
                }
                fatalError("gtfs.db not found in bundle")
            }

            // Read-only configuration
            var config = Configuration()
            config.readonly = true
            config.busyMode = .timeout(5.0)

            // Open database
            dbQueue = try DatabaseQueue(path: path, configuration: config)

            Logger.database.info("database_loaded", metadata: .from(["path": path]))

            // Validate database with more checks
            try dbQueue.read { db in
                let stopsCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM stops") ?? 0
                let routesCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM routes") ?? 0

                Logger.database.info(
                    "database_validated",
                    metadata: .from([
                        "stops_count": stopsCount,
                        "routes_count": routesCount
                    ])
                )

                // Test route decoding
                if let firstRoute = try? Route.fetchOne(db, sql: "SELECT * FROM routes LIMIT 1") {
                    Logger.database.info(
                        "route_decode_test_passed",
                        metadata: .from([
                            "route_id": firstRoute.rid,
                            "route_name": firstRoute.routeShortName ?? "nil"
                        ])
                    )
                } else {
                    Logger.database.warning("route_decode_test_failed")
                }
            }
        } catch {
            Logger.database.error(
                "database_init_failed",
                metadata: .from([
                    "error": error.localizedDescription,
                    "error_type": String(describing: type(of: error))
                ])
            )
            fatalError("Failed to initialize database: \(error)")
        }
    }

    // Read-only access
    func read<T>(_ block: (Database) throws -> T) throws -> T {
        return try dbQueue.read(block)
    }

    // Calendar service filter using bit-packed days (monday=bit0 ... sunday=bit6)
    func isServiceActive(db: Database, serviceId: String, on date: Date) throws -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.sydneyTimeZone

        // Weekday index where Monday=0 ... Sunday=6
        let weekdayIndex = (calendar.component(.weekday, from: date) + 5) % 7

        // Format service_date as yyyy-MM-dd to match stored text columns
        let formatter = Self.serviceDateFormatter
        formatter.timeZone = Self.sydneyTimeZone
        let serviceDate = formatter.string(from: date)

        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT days, start_date, end_date FROM calendar WHERE service_id = ? LIMIT 1",
            arguments: [serviceId]
        ) else {
            return false
        }

        let days: Int = row["days"]
        let startDate: String = row["start_date"]
        let endDate: String = row["end_date"]

        guard startDate <= serviceDate, endDate >= serviceDate else {
            return false
        }

        return (days & (1 << weekdayIndex)) != 0
    }

    private static let sydneyTimeZone = TimeZone(identifier: "Australia/Sydney")!

    // Shared formatter to avoid repeated allocation in tight loops
    private static let serviceDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_AU")
        return formatter
    }()

    private static var cachedHasStartTimeColumn: Bool?
    private static var cachedHasSidOffsetIndex: Bool?

    private static func checkStartTimeColumn(_ db: Database) throws -> Bool {
        if let cached = cachedHasStartTimeColumn {
            return cached
        }
        let hasColumn = try Row.fetchAll(db, sql: "PRAGMA table_info(trips)")
            .contains(where: { (row: Row) in
                let name: String = row["name"]
                return name == "start_time_secs"
            })
        cachedHasStartTimeColumn = hasColumn
        return hasColumn
    }

    private static func checkSidOffsetIndex(_ db: Database) throws -> Bool {
        if let cached = cachedHasSidOffsetIndex { return cached }
        let hasIndex = try Row.fetchAll(db, sql: "PRAGMA index_list('pattern_stops')")
            .contains(where: { (row: Row) in
                let name: String = row["name"]
                return name == "idx_pattern_stops_sid_offset"
            })
        cachedHasSidOffsetIndex = hasIndex
        if !hasIndex {
            Logger.database.warning(
                "missing_sid_offset_index",
                metadata: .from(["index": "idx_pattern_stops_sid_offset"])
            )
        }
        return hasIndex
    }

    // Get departures from offline GRDB (static schedule)
    func getDepartures(stopId: String, limit: Int = 20, currentDate: Date = Date()) throws -> [Departure] {
        return try read { db in
            // Resolve integer sid from dict_stop; return empty if not found
            guard let sid = try Int.fetchOne(db, sql: "SELECT sid FROM dict_stop WHERE stop_id = ?", arguments: [stopId]) else {
                Logger.database.warning(
                    "offline_departures_stop_not_found",
                    metadata: .from(["stop_id": stopId])
                )
                return []
            }

            // Sydney time calculations
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = Self.sydneyTimeZone
            let midnight = calendar.startOfDay(for: currentDate)
            let timeSecs = Int(currentDate.timeIntervalSince(midnight))
            let weekdayIndex = (calendar.component(.weekday, from: currentDate) + 5) % 7 // Monday=0

            let serviceDate = Self.serviceDateFormatter.string(from: currentDate)

            // Detect start_time_secs column once (schema may omit it)
            let hasStartTime = try Self.checkStartTimeColumn(db)
            let actualExpr = hasStartTime ? "(COALESCE(t.start_time_secs, 0) + ps.departure_offset_secs)" : "ps.departure_offset_secs"

            // Check for sid/offset index presence (performance hint)
            _ = try Self.checkSidOffsetIndex(db)

            struct DepartureRow: FetchableRecord, Decodable {
                let tripId: String
                let headsign: String?
                let wheelchairAccessible: Int?
                let routeShortName: String?
                let routeType: Int
                let actualDepartureSecs: Int
            }

            let baseSQL = """
            SELECT
                t.trip_id AS tripId,
                t.trip_headsign AS headsign,
                t.wheelchair_accessible AS wheelchairAccessible,
                r.route_short_name AS routeShortName,
                r.route_type AS routeType,
                \(actualExpr) AS actualDepartureSecs
            FROM pattern_stops ps
            JOIN patterns p ON ps.pid = p.pid
            JOIN trips t ON t.pid = p.pid
            JOIN routes r ON p.rid = r.rid
            JOIN calendar c ON t.service_id = c.service_id
            WHERE ps.sid = ?
              AND c.start_date <= ?
              AND c.end_date >= ?
              AND (c.days & (1 << ?)) != 0
              AND \(actualExpr) BETWEEN ? AND ?
            ORDER BY \(actualExpr) ASC
            LIMIT ?
            """

            func fetchRows(serviceDate: String, weekdayIndex: Int, start: Int, end: Int, limit: Int) throws -> [DepartureRow] {
                try DepartureRow.fetchAll(
                    db,
                    sql: baseSQL,
                    arguments: [sid, serviceDate, serviceDate, weekdayIndex, start, end, limit]
                )
            }

            let startTime = Date()
            var rows = try fetchRows(serviceDate: serviceDate, weekdayIndex: weekdayIndex, start: timeSecs, end: timeSecs + 7200, limit: limit)

            // Overnight handling: include previous day's late trips (offset >= 86400)
            if timeSecs < 3600 {
                if let prevDate = calendar.date(byAdding: .day, value: -1, to: currentDate) {
                    let prevServiceDate = Self.serviceDateFormatter.string(from: prevDate)
                    let prevWeekday = (calendar.component(.weekday, from: prevDate) + 5) % 7
                    let overnightRows = try fetchRows(
                        serviceDate: prevServiceDate,
                        weekdayIndex: prevWeekday,
                        start: timeSecs + 86400,
                        end: timeSecs + 86400 + 7200,
                        limit: limit
                    )
                    rows.append(contentsOf: overnightRows)
                }
            }

            if !hasStartTime {
                Logger.database.warning(
                    "start_time_secs_column_missing",
                    metadata: .from(["note": "using departure_offset_secs only"])
                )
            }

            // Map to departures, sort, limit
            let departures = rows
                .sorted { $0.actualDepartureSecs < $1.actualDepartureSecs }
                .prefix(limit)
                .map { row in
                    let sched = row.actualDepartureSecs
                    return Departure(
                        tripId: row.tripId,
                        routeShortName: row.routeShortName ?? "",
                        headsign: row.headsign ?? "",
                        scheduledTimeSecs: sched,
                        realtimeTimeSecs: sched,
                        delayS: 0,
                        realtime: false,
                        platform: nil,
                        wheelchairAccessible: row.wheelchairAccessible ?? 0,
                        occupancy_status: nil
                    )
                }

            let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
            Logger.database.info(
                "offline_departures_query",
                metadata: .from([
                    "stop_id": stopId,
                    "count": departures.count,
                    "duration_ms": durationMs
                ])
            )

            return departures
        }
    }
}
